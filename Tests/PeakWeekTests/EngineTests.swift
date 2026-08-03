import XCTest
@testable import PeakWeek

/// Locks in the trusted engine numbers. The engine is a direct port of a fully
/// tested JS implementation — these tests exist so future features can't silently
/// change percentages, rep schemes, block allocation, or export text.
final class EngineTests: XCTestCase {

    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)
    var client: Client { Client(name: "Test", unit: .lb, maxes: maxes) }

    // MARK: - Block allocation

    func testFullPrep12WeeksBlockLayout() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        XCTAssertEqual(p.blocks.map(\.phase), [.acc, .deload, .trans, .real, .meet])
        XCTAssertEqual(p.blocks.map(\.weeks), [4, 1, 4, 2, 1])
        XCTAssertEqual(p.weeks.count, 12)
    }

    func testFullPrepAllLengthsSumAndOrder() {
        for n in 10...16 {
            let p = Engine.buildProgram(startPhase: .full, totalWeeks: n, fiveDay: false)
            XCTAssertEqual(p.blocks.reduce(0) { $0 + $1.weeks }, n, "weeks must sum to \(n)")
            XCTAssertEqual(p.weeks.count, n)
            XCTAssertEqual(p.weeks.last?.phase, .meet, "meet week is always last for full prep")
            // Deload only at 12+ weeks
            let hasDeload = p.blocks.contains { $0.phase == .deload }
            XCTAssertEqual(hasDeload, n >= 12, "deload iff n >= 12 (n=\(n))")
            // Week numbering is contiguous 1...n
            XCTAssertEqual(p.weeks.map(\.num), Array(1...n))
        }
    }

    func testOffSeasonLayout() {
        let p = Engine.buildProgram(startPhase: .offseason, totalWeeks: 10, fiveDay: false)
        XCTAssertEqual(p.blocks.map(\.phase), [.acc, .deload, .trans])
        XCTAssertEqual(p.blocks.reduce(0) { $0 + $1.weeks }, 10)
        XCTAssertFalse(p.weeks.contains { $0.phase == .meet }, "off-season has no meet week")
    }

    func testSingleBlockPrograms() {
        let acc = Engine.buildProgram(startPhase: .acc, totalWeeks: 5, fiveDay: false)
        XCTAssertEqual(acc.blocks.map(\.phase), [.acc])
        XCTAssertEqual(acc.weeks.count, 5)
        XCTAssertFalse(acc.weeks.contains { $0.phase == .meet })

        let real = Engine.buildProgram(startPhase: .real, totalWeeks: 3, fiveDay: false)
        XCTAssertEqual(real.weeks.count, 3)
        XCTAssertEqual(real.weeks.last?.phase, .meet, "peaking-only block ends in meet week")
    }

    // MARK: - Week 1 Day 1 canonical numbers (smoke-test spec)

    func testWeek1Day1CompetitionSquat() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        let s = p.weeks[0].days[0].slots[0]
        XCTAssertEqual(Engine.slotName(s), "Competition Squat")
        XCTAssertEqual(s.sets, 4)
        XCTAssertEqual(s.reps, 6)
        XCTAssertEqual(s.pct, 67)
        XCTAssertEqual(Engine.slotLoad(s, maxes: maxes, unit: .lb), 270)
    }

    func testAccumulationLinearProgression() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        // Acc block is weeks 1-4; main squat climbs linearly 67 -> 75
        let accWeeks = p.weeks.filter { $0.phase == .acc }
        let pcts = accWeeks.map { $0.days[0].slots[0].pct! }
        XCTAssertEqual(pcts.first, 67)
        XCTAssertEqual(pcts.last, 75)
        XCTAssertEqual(pcts, pcts.sorted(), "percentage climbs monotonically within block")
    }

    // MARK: - Load math

    func testRoundLoadSteps() {
        XCTAssertEqual(Engine.roundLoad(271.35, unit: .lb), 270)
        XCTAssertEqual(Engine.roundLoad(272.5, unit: .lb), 275)
        XCTAssertEqual(Engine.roundLoad(101.2, unit: .kg), 100)   // 40.48 steps rounds down
        XCTAssertEqual(Engine.roundLoad(101.3, unit: .kg), 102.5) // 40.52 steps rounds up
        XCTAssertEqual(Engine.roundLoad(1, unit: .lb), 5, "load never rounds below one step")
        XCTAssertEqual(Engine.roundLoad(1, unit: .kg), 2.5)
    }

    func testVariationLoadUsesModifier() {
        // Pause Squat mod 0.9: 405 * 0.67 * 0.9 = 244.215 -> 245
        let s = Slot(pool: .squat, exIdx: 1, sets: 3, reps: 6, pct: 67, rpe: 7)
        XCTAssertEqual(Engine.slotLoad(s, maxes: maxes, unit: .lb), 245)
    }

    func testAccessoryAndCustomSlotsHaveNoLoad() {
        let accessory = Slot(pool: .quads, exIdx: 0, sets: 3, reps: 10, pct: nil, rpe: 8)
        XCTAssertNil(Engine.slotLoad(accessory, maxes: maxes, unit: .lb))
        var custom = Slot(pool: .squat, exIdx: 0, sets: 3, reps: 5, pct: 75, rpe: 8)
        custom.custom = "Belt Squat"
        XCTAssertNil(Engine.slotLoad(custom, maxes: maxes, unit: .lb), "custom exercises have no computed load")
        XCTAssertEqual(Engine.slotName(custom), "Belt Squat")
    }

    func testZeroMaxProducesNoLoad() {
        let s = Slot(pool: .squat, exIdx: 0, sets: 4, reps: 6, pct: 67, rpe: 7)
        XCTAssertNil(Engine.slotLoad(s, maxes: Maxes(), unit: .lb))
    }

    // MARK: - Attempts

    func testAttemptPercentages() {
        let a = Engine.attempts(max: 405, unit: .lb)
        XCTAssertEqual(a.opener, 370)   // 405 * .91  = 368.55 -> 370
        XCTAssertEqual(a.second, 395)   // 405 * .97  = 392.85 -> 395
        XCTAssertEqual(a.third, 410)    // 405 * 1.015 = 411.075 -> 410
        let kg = Engine.attempts(max: 250, unit: .kg)
        XCTAssertEqual(kg.opener, 227.5)
        XCTAssertEqual(kg.second, 242.5)
        XCTAssertEqual(kg.third, 252.5)
    }

    // MARK: - Day templates

    func testFiveDayOnlyAddsToAccAndTrans() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: true)
        for w in p.weeks {
            let expected: Int
            switch w.phase {
            case .acc, .trans: expected = 5
            case .deload, .real: expected = 4
            case .meet: expected = 2
            }
            XCTAssertEqual(w.days.count, expected, "week \(w.num) (\(w.phase)) day count")
        }
    }

    func testRealizationTaperStructure() {
        // Realization block in 12-wk prep: 2 training weeks + meet week.
        // weeksOut counts down; last heavy DL day appears at weeksOut == 2 template.
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 14, fiveDay: false)
        let realWeeks = p.weeks.filter { $0.phase == .real }
        XCTAssertFalse(realWeeks.isEmpty)
        let titles = realWeeks.flatMap { $0.days.map(\.title) }
        XCTAssertTrue(titles.contains { $0.contains("LAST HEAVY DEADLIFT") },
                      "14-wk prep includes last-heavy-deadlift day 10-14 days out")
        XCTAssertTrue(titles.contains { $0.contains("OPENER") },
                      "openers taken in final training week")
    }

    func testMeetWeekIsLightTechniqueOnly() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        let meet = p.weeks.last!
        XCTAssertEqual(meet.days.count, 2)
        let allPcts = meet.days.flatMap { $0.slots.compactMap(\.pct) }
        XCTAssertTrue(allPcts.allSatisfy { $0 <= 60 }, "meet week never exceeds 60%")
        XCTAssertTrue(meet.days.last!.slots.isEmpty, "back half of meet week is rest")
    }

    // MARK: - RPE table integrity

    func testRPETableShape() {
        XCTAssertEqual(Engine.rpeTable.map(\.reps), [1, 2, 3, 4, 5, 6, 8, 10])
        for row in Engine.rpeTable {
            XCTAssertEqual(row.row.map(\.rpe), [7, 7.5, 8, 8.5, 9, 9.5, 10])
            let pcts = row.row.map(\.pct)
            XCTAssertEqual(pcts, pcts.sorted(), "% rises with RPE for \(row.reps) reps")
        }
        // Anchor values from the RTS chart
        XCTAssertEqual(Engine.rpeTable[0].row.last?.pct, 100, "1 rep @ RPE 10 = 100%")
        XCTAssertEqual(Engine.rpeTable[2].row.first?.pct, 84,  "3 reps @ RPE 7 = 84%")
    }

    // MARK: - Exercise pools

    func testPoolIntegrity() {
        for (pool, exs) in Engine.pools {
            XCTAssertFalse(exs.isEmpty, "\(pool) pool is non-empty")
            let names = exs.map(\.name)
            XCTAssertEqual(Set(names).count, names.count, "\(pool) has no duplicate names")
        }
        // Comp lifts are index 0 with mod 1.0
        for pool in [LiftPool.squat, .bench, .deadlift] {
            XCTAssertEqual(Engine.pools[pool]?.first?.mod, 1.0, "\(pool) index 0 is the comp lift")
        }
        // Accessory pools carry no load modifiers
        for pool in [LiftPool.quads, .hams, .back, .press] {
            XCTAssertTrue(Engine.pools[pool]!.allSatisfy { $0.mod == nil })
        }
    }

    // MARK: - Week export text

    func testWeekToTextFormat() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        let text = Engine.weekToText(client: client, program: p, week: p.weeks[0])
        XCTAssertTrue(text.contains("TEST — WEEK 1 of 12 — ACCUMULATION"))
        XCTAssertTrue(text.contains("Competition Squat — 4x6 @ 67% → 270 lb · RPE 7"))
        XCTAssertTrue(text.contains("RPE guide:"))
    }

    func testMeetWeekExportIncludesAttempts() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        let text = Engine.weekToText(client: client, program: p, week: p.weeks.last!)
        XCTAssertTrue(text.contains("MEET DAY ATTEMPTS"))
        XCTAssertTrue(text.contains("Squat: open 370 / second 395 / third 410 lb"))
        XCTAssertTrue(text.contains("Rest. Sleep 8+, eat, hydrate."))
    }

    func testCoachNotesAppearInExport() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false)
        var week = p.weeks[0]
        week.note = "Bring knee sleeves Thursday."
        let text = Engine.weekToText(client: client, program: p, week: week)
        XCTAssertTrue(text.contains("COACH NOTES: Bring knee sleeves Thursday."))
    }

    // MARK: - Persistence round-trip

    func testCodableRoundTrip() throws {
        var c = client
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        // ISO8601 drops sub-second precision, so compare after one normalizing pass:
        // decode(encode(x)) must be a fixed point.
        let once = try dec.decode(AppData.self, from: enc.encode(AppData(clients: [c])))
        let twice = try dec.decode(AppData.self, from: enc.encode(once))
        XCTAssertEqual(once.clients, twice.clients, "AppData is stable across JSON round-trips")
        XCTAssertEqual(once.clients.first?.id, c.id)
        XCTAssertEqual(once.clients.first?.program?.weeks.count, 12)
    }
}
