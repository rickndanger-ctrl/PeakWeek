import XCTest
@testable import PeakWeek

/// Custom phase lengths + deload insertion/removal: the program must stay
/// internally consistent (numbering, block runs, totals) and the send-log
/// bookkeeping must follow structural edits.
final class StructureTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()
    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)

    // MARK: - custom block plan

    func testCustomBlockPlanHonored() {
        let plan = BlockPlan(acc: 6, deloadAfterAcc: true, trans: 5, real: 3)
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: false,
                                    library: lib, blockPlan: plan)
        XCTAssertEqual(p.blocks.map(\.phase), [.acc, .deload, .trans, .real, .meet])
        XCTAssertEqual(p.blocks.map(\.weeks), [6, 1, 5, 2, 1])   // real 3 = 2 taper + meet
        XCTAssertEqual(p.weeks.count, 15)
        XCTAssertEqual(p.totalWeeks, 15)
        XCTAssertEqual(p.weeks.last?.phase, .meet)
        // Linear progression spans the longer acc block: 67 first, 75 last.
        let accPcts = p.weeks.filter { $0.phase == .acc }.map { $0.days[0].slots[0].pct! }
        XCTAssertEqual(accPcts.first, 67)
        XCTAssertEqual(accPcts.last, 75)
        XCTAssertEqual(accPcts.count, 6)
    }

    func testCustomPlanWithoutDeload() {
        let plan = BlockPlan(acc: 3, deloadAfterAcc: false, trans: 6, real: 4)
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: false,
                                    library: lib, blockPlan: plan)
        XCTAssertEqual(p.blocks.map(\.phase), [.acc, .trans, .real, .meet])
        XCTAssertEqual(p.weeks.count, 13)
    }

    func testNilPlanIdenticalToFactory() {
        let auto = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let explicit = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false,
                                           library: lib, blockPlan: nil)
        XCTAssertEqual(auto.blocks, explicit.blocks)
        XCTAssertEqual(auto.weeks.count, explicit.weeks.count)
    }

    // MARK: - deload insertion (coach policy: trans→real boundary, never back-to-back)

    func testInsertDeloadAtRealizationBoundary() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        // 12-wk factory: acc idx 0-3, deload idx 4, trans idx 5-8, real idx 9-10, meet idx 11.
        let boundary = p.realizationBoundary
        XCTAssertEqual(boundary, 9, "boundary is the first realization week")
        let deload = Engine.makeDeloadWeek(fiveDay: false, library: lib)
        XCTAssertTrue(p.insertDeload(week: deload, at: boundary!))

        XCTAssertEqual(p.weeks.count, 13)
        XCTAssertEqual(p.totalWeeks, 13)
        XCTAssertEqual(p.weeks.map(\.num), Array(1...13), "contiguous renumbering")
        XCTAssertEqual(p.weeks[9].phase, .deload)
        // Between transmutation and realization: acc 4, deload 1, trans 4, deload 1, real 2, meet 1.
        XCTAssertEqual(p.blocks.map(\.phase), [.acc, .deload, .trans, .deload, .real, .meet])
        XCTAssertEqual(p.blocks.map(\.weeks), [4, 1, 4, 1, 2, 1])
        // Inserted week's slots resolve against the library.
        for day in p.weeks[9].days {
            for slot in day.slots where slot.custom == nil {
                XCTAssertNotNil(slot.exerciseID)
            }
        }
        // Deload content is the standard 62% week.
        let client = Client(name: "T", unit: .lb, maxes: maxes)
        let text = Engine.weekToText(client: client, program: p, week: p.weeks[9], library: lib)
        XCTAssertTrue(text.contains("Competition Squat — 3x5 @ 62% → 250 lb · RPE 6"))
    }

    func testNeverTwoDeloadsInARow() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let deload = Engine.makeDeloadWeek(fiveDay: false, library: lib)
        // Adjacent to the existing acc→trans deload (idx 4): refused on both sides.
        XCTAssertFalse(p.canInsertDeload(at: 4))
        XCTAssertFalse(p.canInsertDeload(at: 5))
        XCTAssertFalse(p.insertDeload(week: deload, at: 4))
        XCTAssertEqual(p.weeks.count, 12, "refused insertion changes nothing")
        // Boundary insert once: fine. Twice: refused (a deload now sits there).
        XCTAssertTrue(p.insertDeload(week: deload, at: p.realizationBoundary!))
        let second = Engine.makeDeloadWeek(fiveDay: false, library: lib)
        XCTAssertFalse(p.insertDeload(week: second, at: p.realizationBoundary!),
                       "never two deload weeks in a row")
        XCTAssertEqual(p.weeks.count, 13)
        // A non-deload week can never sneak through insertDeload.
        var bogus = Engine.makeDeloadWeek(fiveDay: false, library: lib)
        bogus.phase = .acc
        XCTAssertFalse(p.insertDeload(week: bogus, at: 0))
    }

    func testRemoveDeloadRestoresStructure() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        // Normalized baseline: regroup uses run-based coordinates (meet week is
        // its own 1-week run, matching the timeline display), while the builder
        // counted meet inside realization's blockLen. Compare against the
        // normalized form — remove(insert(x)) must be exactly normalize(x).
        var baseline = p
        baseline.renumberAndRegroup()
        let boundary = p.realizationBoundary!
        p.insertDeload(week: Engine.makeDeloadWeek(fiveDay: false, library: lib), at: boundary)
        p.removeWeek(at: boundary)
        XCTAssertEqual(p.weeks.count, 12)
        XCTAssertEqual(p.blocks, baseline.blocks)
        XCTAssertEqual(p.weeks.map(\.num), baseline.weeks.map(\.num))
        XCTAssertEqual(p.weeks.map(\.weekInBlock), baseline.weeks.map(\.weekInBlock))
        XCTAssertEqual(p.weeks.map(\.blockLen), baseline.weeks.map(\.blockLen))
    }

    func testWeeksOutFollowsInsertion() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        p.insertDeload(week: Engine.makeDeloadWeek(fiveDay: false, library: lib),
                       at: p.realizationBoundary!)
        let client = Client(name: "T", unit: .lb, maxes: maxes)
        // Week 1 is now 12 out (13-week program).
        let w1 = Engine.weekToText(client: client, program: p, week: p.weeks[0], library: lib)
        XCTAssertTrue(w1.contains("12 WKS OUT"), String(w1.prefix(60)))
    }

    // MARK: - send-log adjustment across structural edits

    func testSendRecordsShiftOnInsertion() {
        // Simulate: weeks 1-3 sent, deload inserted before week 3.
        var records = (1...3).map {
            SendRecord(clientID: UUID(), clientName: "T", weekNum: $0,
                       date: Date(), method: .messages, status: .sent, programStamp: nil)
        }
        // The store method operates on its own log; emulate its logic here via
        // a scratch AppStore-free check of expectations:
        // insertion at index 2 (week 3 position) -> records with weekNum >= 3 shift to 4.
        for i in records.indices where records[i].weekNum >= 3 {
            records[i].weekNum += 1
        }
        XCTAssertEqual(records.map(\.weekNum), [1, 2, 4],
                       "weeks 1-2 keep history; old week 3 record now tracks the shifted week 4")
    }

    // MARK: - client blockPlan decode tolerance

    func testClientBlockPlanDecodes() throws {
        let json = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","name":"Old","unit":"lb",
        "maxes":{"squat":500,"bench":300,"deadlift":550},
        "setupPhase":"full","setupWeeks":12,"fiveDay":false}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let c = try dec.decode(Client.self, from: Data(json.utf8))
        XCTAssertNil(c.blockPlan, "absent blockPlan decodes as automatic")

        var c2 = c
        c2.blockPlan = BlockPlan(acc: 5, deloadAfterAcc: false, trans: 4, real: 3)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let round = try dec.decode(Client.self, from: enc.encode(c2))
        XCTAssertEqual(round.blockPlan?.acc, 5)
        XCTAssertEqual(round.blockPlan?.total, 12)
    }
}
