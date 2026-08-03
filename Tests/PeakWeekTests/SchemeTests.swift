import XCTest
@testable import PeakWeek

/// Opt-in scheme pins (wave / DUP / hypertrophy) — the researched numbers,
/// locked. Factory output stays untouched (covered by golden tests).
final class SchemeTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()
    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)

    // MARK: - wave transmutation

    func testWaveN6WorkedExample() {
        // Spec worked example, squat: 76.5/80/83.5 then 79/82.5/86.
        let expected: [Double] = [76.5, 80, 83.5, 79, 82.5, 86]
        for (i, e) in expected.enumerated() {
            let w = Engine.waveOverride(week: i + 1, blockLen: 6, lift: .squat)!
            XCTAssertEqual(w.pct, e, "week \(i + 1)")
        }
        // Reps cycle 5/4/3, sets always 4.
        XCTAssertEqual(Engine.waveOverride(week: 1, blockLen: 6, lift: .squat)?.reps, 5)
        XCTAssertEqual(Engine.waveOverride(week: 3, blockLen: 6, lift: .squat)?.reps, 3)
        XCTAssertEqual(Engine.waveOverride(week: 4, blockLen: 6, lift: .squat)?.sets, 4)
    }

    func testWaveAlwaysEndsOnTopWave() {
        for n in 3...10 {
            let sq = Engine.waveOverride(week: n, blockLen: n, lift: .squat)!
            let bp = Engine.waveOverride(week: n, blockLen: n, lift: .bench)!
            let dl = Engine.waveOverride(week: n, blockLen: n, lift: .deadlift)!
            XCTAssertEqual(sq.pct, 86, "N=\(n)")
            XCTAssertEqual(bp.pct, 85, "N=\(n)")
            XCTAssertEqual(dl.pct, 87, "N=\(n)")
            XCTAssertEqual(sq.reps, 3)
            XCTAssertEqual(dl.reps, 2, "DL waves run 4/3/2")
        }
        // N=8 opens 4×4 @ 77.5 (truncated wave 1 front) — near factory 77.
        let open = Engine.waveOverride(week: 1, blockLen: 8, lift: .squat)!
        XCTAssertEqual(open.pct, 77.5)
        XCTAssertEqual(open.reps, 4)
    }

    func testWaveAppliesOnlyToPrimaryLifts() {
        var plan = BlockPlan(acc: 4, deloadAfterAcc: true, trans: 6, real: 3)
        plan.transScheme = .wave
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: false,
                                    library: lib, blockPlan: plan)
        let transWeeks = p.weeks.filter { $0.phase == .trans }
        XCTAssertEqual(transWeeks.count, 6)
        // Week 1 of trans: primary squat = wave (4×5 @ 76.5), secondary pause
        // squat keeps the factory lerp (2×3 @ 70).
        let w1 = transWeeks[0]
        XCTAssertEqual(w1.days[0].slots[0].pct, 76.5)
        XCTAssertEqual(w1.days[0].slots[0].reps, 5)
        XCTAssertEqual(w1.days[0].slots[1].pct, 70, "secondary untouched")
        // DL day RPE stays 8 through the wave.
        XCTAssertEqual(w1.days[2].slots[0].rpe, 8)
        // Final trans week tops out identically to linear's destination band.
        let wLast = transWeeks[5]
        XCTAssertEqual(wLast.days[0].slots[0].pct, 86)
        XCTAssertEqual(wLast.days[1].slots[0].pct, 85)
        XCTAssertEqual(wLast.days[2].slots[0].pct, 87)
        // Realization untouched (3-wk peaking: first week = 2-out heavy doubles @90).
        let real3 = p.weeks.first { $0.phase == .real }!
        XCTAssertEqual(real3.days[0].slots[0].pct, 90)
    }

    func testLinearSchemeIdenticalToFactory() {
        let plain = BlockPlan(acc: 4, deloadAfterAcc: true, trans: 4, real: 3)
        let p1 = Engine.buildProgram(startPhase: .full, totalWeeks: plain.total, fiveDay: false,
                                     library: lib, blockPlan: plain)
        let p2 = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let c = Client(name: "T", unit: .lb, maxes: maxes)
        for (a, b) in zip(p1.weeks, p2.weeks) {
            XCTAssertEqual(Engine.weekToText(client: c, program: p1, week: a, library: lib),
                           Engine.weekToText(client: c, program: p2, week: b, library: lib))
        }
    }

    // MARK: - DUP accumulation

    func testDUPFourDayZonesAndBands() {
        var plan = BlockPlan(acc: 6, deloadAfterAcc: true, trans: 4, real: 3)
        plan.accScheme = .dup
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: false,
                                    library: lib, blockPlan: plan)
        let acc = p.weeks.filter { $0.phase == .acc }
        XCTAssertEqual(acc.count, 6)
        // Week 1 (odd): day 1 squat = H 4×8 @ 65; day 4 = speed CGB + comp S.
        let w1 = acc[0]
        XCTAssertEqual(w1.days[0].slots[0].reps, 8)
        XCTAssertEqual(w1.days[0].slots[0].pct, 65)
        XCTAssertEqual(w1.days[3].slots[0].note, "max bar speed")
        XCTAssertEqual(w1.days[3].slots[0].reps, 3)
        XCTAssertEqual(w1.days[3].slots[1].reps, 5, "comp bench strength exposure")
        // Week 2 (even): day 1 squat = S 4×5.
        XCTAssertEqual(acc[1].days[0].slots[0].reps, 5)
        // Bench volume day band ends at 71 in the final week.
        XCTAssertEqual(acc[5].days[1].slots[0].pct, 71)
        // DL day: S-DL 4×4 hitting 82 by the last week.
        XCTAssertEqual(acc[5].days[2].slots[0].reps, 4)
        XCTAssertEqual(acc[5].days[2].slots[0].pct, 82)
        // Day-1 parity lerp: odd weeks 1/3/5 climb 65 → 71.
        XCTAssertEqual(acc[2].days[0].slots[0].pct, 68)
        XCTAssertEqual(acc[4].days[0].slots[0].pct, 71)
        // Trans/real untouched.
        XCTAssertEqual(p.weeks.first { $0.phase == .trans }!.days[0].slots[0].pct, 77)
    }

    func testDUPFiveDaySplitsSquatExposures() {
        var plan = BlockPlan(acc: 4, deloadAfterAcc: true, trans: 4, real: 3)
        plan.accScheme = .dup
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: plan.total, fiveDay: true,
                                    library: lib, blockPlan: plan)
        let w1 = p.weeks.first { $0.phase == .acc }!
        XCTAssertEqual(w1.days.count, 5)
        XCTAssertEqual(w1.days[0].slots[0].reps, 8, "day 1 = volume squat")
        XCTAssertEqual(w1.days[4].slots[0].reps, 5, "day 5 = strength squat")
        XCTAssertEqual(w1.days[4].slots[0].pct, 75)
    }

    // MARK: - hypertrophy off-season

    func testHypSpineTwelveWeeks() {
        let p = Engine.buildProgram(startPhase: .hypertrophy, totalWeeks: 12, fiveDay: false,
                                    library: lib)
        XCTAssertEqual(p.weeks.count, 12)
        XCTAssertEqual(p.blocks.map(\.phase), [.hyp, .deload, .hyp, .deload, .hyp])
        XCTAssertEqual(p.blocks.map(\.weeks), [4, 1, 4, 1, 2])
        XCTAssertFalse(p.weeks.contains { $0.phase == .meet }, "no meet week off-season")
        // Meso spine: 4×12 @ 60..63, deload, 4×10 @ 64..68, deload, 4×8 @ 70/72.
        let mains = p.weeks.map { $0.phase == .deload ? nil : $0.days[0].slots[0] }
        XCTAssertEqual(mains[0]?.reps, 12); XCTAssertEqual(mains[0]?.pct, 60)
        XCTAssertEqual(mains[3]?.reps, 12); XCTAssertEqual(mains[3]?.pct, 63)
        XCTAssertNil(mains[4])
        XCTAssertEqual(mains[5]?.reps, 10); XCTAssertEqual(mains[5]?.pct, 64)
        XCTAssertEqual(mains[8]?.pct, 68)
        XCTAssertNil(mains[9])
        XCTAssertEqual(mains[10]?.reps, 8); XCTAssertEqual(mains[10]?.pct, 70)
        XCTAssertEqual(mains[11]?.pct, 72)
        // Main = High-Bar (mod 0.92): 405 × 0.60 × 0.92 = 223.56 → 225.
        let c = Client(name: "T", unit: .lb, maxes: maxes)
        XCTAssertEqual(Engine.slotLoad(p.weeks[0].days[0].slots[0], maxes: maxes,
                                       unit: .lb, library: lib), 225)
        // Secondary = 3×8 @ main−2.
        XCTAssertEqual(p.weeks[0].days[0].slots[1].pct, 58)
        XCTAssertEqual(p.weeks[0].days[0].slots[1].reps, 8)
        // Accessory ramp: 3 sets weeks 1-2, 4 sets weeks 3-4 (first two accessories).
        XCTAssertEqual(p.weeks[0].days[0].slots[2].sets, 3)
        XCTAssertEqual(p.weeks[2].days[0].slots[2].sets, 4)
        // Deload weeks are the factory deload verbatim.
        let text = Engine.weekToText(client: c, program: p, week: p.weeks[4], library: lib)
        XCTAssertTrue(text.contains("Competition Squat — 3x5 @ 62% → 250 lb · RPE 6"))
    }

    func testHypSpineVariants() {
        for (n, phases, weeksPerBlock) in [
            (8, [Phase.hyp, .deload, .hyp], [4, 1, 3]),
            (9, [Phase.hyp, .deload, .hyp], [4, 1, 4]),
            (10, [Phase.hyp, .deload, .hyp], [4, 1, 5]),
            (11, [Phase.hyp, .deload, .hyp, .deload, .hyp], [4, 1, 4, 1, 1]),
        ] {
            let p = Engine.buildProgram(startPhase: .hypertrophy, totalWeeks: n, fiveDay: false,
                                        library: lib)
            XCTAssertEqual(p.weeks.count, n, "n=\(n)")
            XCTAssertEqual(p.blocks.map(\.phase), phases, "n=\(n)")
            XCTAssertEqual(p.blocks.map(\.weeks), weeksPerBlock, "n=\(n)")
        }
    }

    func testHypFiveDayAddsSquatVolumeDay() {
        let p = Engine.buildProgram(startPhase: .hypertrophy, totalWeeks: 12, fiveDay: true,
                                    library: lib)
        let w1 = p.weeks[0]
        XCTAssertEqual(w1.days.count, 5)
        XCTAssertEqual(Engine.slotName(w1.days[4].slots[0], library: lib), "Safety Bar Squat")
    }

    // MARK: - peak projection

    func testProjectionOnAlignedTwelveWeekPrep() {
        let cal = Calendar.current
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day))!
        }
        // Day one Mon Aug 10; 12-wk prep; meet on the FINAL day: Sun Nov 1.
        let start = d(2026, 8, 10)
        let meet = d(2026, 11, 1)
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let proj = PeakProjection.compute(program: p, startDate: start, meetDate: meet)!
        XCTAssertNil(proj.meetPlacementNote, "meet on day 7 of the final week is aligned")
        let by = Dictionary(uniqueKeysWithValues: proj.events.map { ($0.kind, $0) })
        // Heavy-double week = week 10 (2 out): day1 Mon Oct 12 → 20 d out is
        // OUTSIDE the squat window (6-12) — the factory's conservative layout
        // gets an honest flag; DL day3 Oct 14 → 18 d out vs 8-16 flagged too.
        XCTAssertEqual(by[.lastHeavySquat]?.daysOut, 20)
        XCTAssertEqual(by[.lastHeavySquat]?.ok, false)
        XCTAssertEqual(by[.lastHeavyDeadlift]?.daysOut, 18)
        // Opener week = week 11: day1 Mon Oct 19 → 13 d out (window 4-10: flagged).
        XCTAssertEqual(by[.openers]?.daysOut, 13)
        // Cessation: meet week day3 = Wed Oct 28 → 4 d out ✓ (2-7).
        XCTAssertEqual(by[.cessation]?.daysOut, 4)
        XCTAssertEqual(by[.cessation]?.ok, true)
    }

    func testProjectionFlagsEarlyMeetPlacement() {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 8, day: 10))!
        // Meet on the MONDAY of the final week (day 1) — early placement.
        let meet = cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let proj = PeakProjection.compute(program: p, startDate: start, meetDate: meet)!
        XCTAssertNotNil(proj.meetPlacementNote)
    }

    func testProjectionOnlyForMeetTrackPrograms() {
        let start = Date()
        let off = Engine.buildProgram(startPhase: .hypertrophy, totalWeeks: 12, fiveDay: false,
                                      library: lib)
        XCTAssertNil(PeakProjection.compute(program: off, startDate: start,
                                            meetDate: start.addingTimeInterval(86400 * 60)))
    }

    // MARK: - decode tolerance

    func testSchemeFieldsDecodeTolerantly() throws {
        let json = """
        {"acc": 5, "deloadAfterAcc": true, "trans": 4, "real": 3}
        """
        let plan = try JSONDecoder().decode(BlockPlan.self, from: Data(json.utf8))
        XCTAssertEqual(plan.accScheme, .linear, "absent scheme = factory linear")
        XCTAssertEqual(plan.transScheme, .linear)
    }
}
