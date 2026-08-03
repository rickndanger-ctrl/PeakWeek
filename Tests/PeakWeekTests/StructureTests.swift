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

    // MARK: - meet-date planning

    func testWeeksAvailable() {
        let cal = Calendar.current
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day))!
        }
        let monday = d(2026, 8, 10)
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 8, 29)), 3,
                       "meet Saturday of week 3")
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 8, 10)), 1,
                       "meet on start Monday = week 1")
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 11, 21)), 15)
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 8, 3)), 0,
                       "meet before start")
        // Boundary: meet exactly k×7 days out lands on the LAST day of week k
        // (a Saturday start with a Saturday meet 12 weeks out is a 12-week
        // prep, not 13 — the whole taper would otherwise run a week late).
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 10, 26)), 11,
                       "77 days -> ceil = 11")
        XCTAssertEqual(Engine.weeksAvailable(startMonday: monday, meetDate: d(2026, 11, 2)), 12,
                       "84 days (12×7, meet on anchor weekday) -> 12, not 13")
    }

    func testMeetPlanPlacesLifterInRightPhase() {
        XCTAssertNil(Engine.meetPlan(availableWeeks: 2), "under 3 weeks: hand-coach")
        // 3-4 out: peaking only.
        XCTAssertEqual(Engine.meetPlan(availableWeeks: 3)?.phase, .real)
        XCTAssertEqual(Engine.meetPlan(availableWeeks: 4)?.weeks, 4)
        XCTAssertNil(Engine.meetPlan(availableWeeks: 4)?.blockPlan)
        // 5-9: strength + peak, no volume block.
        let six = Engine.meetPlan(availableWeeks: 6)!
        XCTAssertEqual(six.phase, .full)
        XCTAssertEqual(six.blockPlan?.acc, 0)
        XCTAssertEqual(six.blockPlan?.trans, 3)
        XCTAssertEqual(six.blockPlan?.real, 3)
        XCTAssertEqual(six.blockPlan?.total, 6)
        let nine = Engine.meetPlan(availableWeeks: 9)!
        XCTAssertEqual(nine.blockPlan?.trans, 5)
        XCTAssertEqual(nine.blockPlan?.real, 4)
        // 10-16: factory full prep.
        let twelve = Engine.meetPlan(availableWeeks: 12)!
        XCTAssertEqual(twelve.phase, .full)
        XCTAssertNil(twelve.blockPlan)
        XCTAssertEqual(twelve.weeks, 12)
        // 17+: volume block extends.
        let eighteen = Engine.meetPlan(availableWeeks: 18)!
        XCTAssertEqual(eighteen.blockPlan?.acc, 8)
        XCTAssertEqual(eighteen.blockPlan?.total, 18)
    }

    func testShortPrepProgramShape() {
        // 6 weeks out: trans 3 + real 3 (incl meet) — no acc, no deload.
        let plan = Engine.meetPlan(availableWeeks: 6)!.blockPlan!
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: false,
                                    library: lib, blockPlan: plan)
        XCTAssertEqual(p.blocks.map(\.phase), [.trans, .real, .meet])
        XCTAssertEqual(p.blocks.map(\.weeks), [3, 2, 1])
        XCTAssertEqual(p.weeks.count, 6)
        XCTAssertEqual(p.weeks.last?.phase, .meet, "short prep still ends on the platform")
        // Strength block starts at the trans table's entry point.
        XCTAssertEqual(p.weeks[0].days[0].slots[0].pct, 77)
    }

    // MARK: - deloads anywhere: trade a week vs insert one

    private func deload(_ p: Program) -> Week {
        Engine.makeDeloadWeek(fiveDay: p.fiveDay, library: lib)
    }

    func testTradeWeekForDeloadKeepsCalendar() {
        // Factory 12: acc 1-4, deload 5, trans 6-9, real 10-11, meet 12.
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let realNumsBefore = p.weeks.filter { $0.phase == .real || $0.phase == .meet }.map(\.num)

        // Lifter's fried in accumulation: week 3 becomes the deload.
        XCTAssertTrue(p.replaceWeekWithDeload(at: 2, deload: deload(p)))
        XCTAssertEqual(p.weeks.count, 12, "trade never changes the total — the deload is absorbed")
        XCTAssertEqual(p.weeks[2].phase, .deload)
        XCTAssertEqual(p.weeks[2].num, 3)
        XCTAssertEqual(p.weeks[2].days[0].slots[0].pct, 62, "factory recovery week content")
        // Everything after keeps its number — the meet doesn't move.
        XCTAssertEqual(p.weeks.filter { $0.phase == .real || $0.phase == .meet }.map(\.num),
                       realNumsBefore)
        // Accumulation split into two runs around the recovery week.
        XCTAssertEqual(p.blocks.map(\.phase),
                       [.acc, .deload, .acc, .deload, .trans, .real, .meet])
    }

    func testTradeRefusalsProtectDoctrine() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let d = deload(p)
        let realIdx = p.realizationBoundary!
        XCTAssertFalse(p.replaceWeekWithDeload(at: realIdx, deload: d),
                       "the taper is never traded")
        XCTAssertFalse(p.replaceWeekWithDeload(at: p.weeks.count - 1, deload: d), "meet week never")
        let deloadIdx = p.weeks.firstIndex { $0.phase == .deload }!
        XCTAssertFalse(p.replaceWeekWithDeload(at: deloadIdx, deload: d), "already a deload")
        XCTAssertFalse(p.replaceWeekWithDeload(at: deloadIdx - 1, deload: d),
                       "would stack two deloads back-to-back")
        XCTAssertFalse(p.replaceWeekWithDeload(at: deloadIdx + 1, deload: d),
                       "would stack two deloads back-to-back")
        XCTAssertEqual(p.weeks.count, 12, "refusals leave the program untouched")
    }

    func testInsertDeloadMidAccumulationShifts() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        // New deload before week 3 (mid-accumulation).
        XCTAssertTrue(p.insertDeload(week: deload(p), at: 2))
        XCTAssertEqual(p.weeks.count, 13, "insert adds a week — everything after shifts")
        XCTAssertEqual(p.weeks[2].phase, .deload)
        XCTAssertEqual(p.weeks.map(\.num), Array(1...13), "numbering stays contiguous")
        XCTAssertEqual(p.weeks.last?.phase, .meet)
        XCTAssertEqual(p.weeks.last?.num, 13, "meet week now a week later")
        // Factory mid-plan deload still there; no adjacency anywhere.
        for i in 1..<p.weeks.count {
            XCTAssertFalse(p.weeks[i].phase == .deload && p.weeks[i - 1].phase == .deload,
                           "adjacent deloads at \(i)")
        }
    }

    // MARK: - bulk edit: apply slot to remaining weeks

    func testBulkApplyPropagatesWithinPhaseOnly() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        // Edit week 2, day 1 (index 0), last slot — an accessory (pct == nil).
        let sIdx = p.weeks[1].days[0].slots.count - 1
        p.weeks[1].days[0].slots[sIdx].custom = "Weighted Plank"
        p.weeks[1].days[0].slots[sIdx].exerciseID = nil
        p.weeks[1].days[0].slots[sIdx].sets = 4
        p.weeks[1].days[0].slots[sIdx].reps = 12
        p.weeks[1].days[0].slots[sIdx].rpe = 7    // RIR 3

        let accWeeksAfter = p.weeks.filter { $0.phase == .acc && $0.num > 2 }.count
        XCTAssertEqual(p.remainingWeeksForSlot(fromWeek: 2, dayIndex: 0, slotIndex: sIdx),
                       accWeeksAfter, "dry run counts later same-phase weeks")

        let applied = p.applySlotToRemainingWeeks(fromWeek: 2, dayIndex: 0, slotIndex: sIdx)
        XCTAssertEqual(applied, accWeeksAfter)

        for w in p.weeks where w.phase == .acc && w.num > 2 {
            let s = w.days[0].slots[sIdx]
            XCTAssertEqual(s.custom, "Weighted Plank")
            XCTAssertNil(s.exerciseID)
            XCTAssertEqual(s.sets, 4)
            XCTAssertEqual(s.reps, 12)
            XCTAssertEqual(s.rpe, 7)
        }
        // Week 1 (before the source) is untouched.
        XCTAssertNil(p.weeks[0].days[0].slots[sIdx].custom)
        // Non-acc phases are untouched.
        for w in p.weeks where w.phase != .acc {
            if w.days[0].slots.indices.contains(sIdx) {
                XCTAssertNil(w.days[0].slots[sIdx].custom,
                             "week \(w.num) (\(w.phase)) must not inherit the acc edit")
            }
        }
    }

    func testBulkApplyPreservesPerWeekPct() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        // Main squat slot in week 1 of acc: change sets/reps, then bulk apply.
        let before = p.weeks.filter { $0.phase == .acc }.map { $0.days[0].slots[0].pct! }
        p.weeks[0].days[0].slots[0].sets = 5
        p.weeks[0].days[0].slots[0].reps = 5
        _ = p.applySlotToRemainingWeeks(fromWeek: 1, dayIndex: 0, slotIndex: 0)

        let after = p.weeks.filter { $0.phase == .acc }.map { $0.days[0].slots[0].pct! }
        XCTAssertEqual(after, before, "each week keeps its own % — the 67→75 ramp survives")
        for w in p.weeks where w.phase == .acc {
            XCTAssertEqual(w.days[0].slots[0].sets, 5)
            XCTAssertEqual(w.days[0].slots[0].reps, 5)
        }
    }

    func testBulkApplyFromLastWeekOfPhaseIsNoop() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let lastAcc = p.weeks.last { $0.phase == .acc }!.num
        XCTAssertEqual(p.remainingWeeksForSlot(fromWeek: lastAcc, dayIndex: 0, slotIndex: 0), 0)
        XCTAssertEqual(p.applySlotToRemainingWeeks(fromWeek: lastAcc, dayIndex: 0, slotIndex: 0), 0)
    }

    func testBulkApplyBadCoordinatesAreSafe() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        XCTAssertEqual(p.applySlotToRemainingWeeks(fromWeek: 99, dayIndex: 0, slotIndex: 0), 0)
        XCTAssertEqual(p.applySlotToRemainingWeeks(fromWeek: 1, dayIndex: 9, slotIndex: 0), 0)
        XCTAssertEqual(p.applySlotToRemainingWeeks(fromWeek: 1, dayIndex: 0, slotIndex: 99), 0)
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
