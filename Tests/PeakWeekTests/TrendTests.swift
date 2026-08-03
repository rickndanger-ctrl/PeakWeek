import XCTest
@testable import PeakWeek

/// Session logging + e1RM trends: entry math, tolerant persistence, unit
/// conversion, block-over-block verdicts, RPE drift, and the stall check-in
/// doctrine (surface signals, never auto-prescribe).
final class TrendTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: s)!
    }

    // MARK: - entry e1RM math

    func testCompE1RMFromTopSet() {
        // 190×4 @8 → table pct 84 → 190/0.84 ≈ 226.19
        let e = LiftLogEntry(date: date("2026-08-03"), lift: .bench, load: 190, reps: 4, rpe: 8)
        XCTAssertEqual(e.compE1RM!, 190 / 0.84, accuracy: 0.01)
        XCTAssertFalse(e.isVariation)
    }

    func testVariationNormalizesThroughModifier() {
        // Pause squat (mod 0.90): 300×3 @8 → e1RM 300/0.86 → comp ≈ /0.9
        let e = LiftLogEntry(date: date("2026-08-03"), lift: .squat,
                             exerciseName: "Pause Squat", loadMod: 0.90,
                             load: 300, reps: 3, rpe: 8)
        XCTAssertEqual(e.compE1RM!, (300 / 0.86) / 0.90, accuracy: 0.01)
        XCTAssertTrue(e.isVariation)
    }

    func testSingleWithoutRPEStandsAsItsOwnFloor() {
        let single = LiftLogEntry(date: date("2026-08-03"), lift: .deadlift, load: 500, reps: 1)
        XCTAssertEqual(single.compE1RM, 500)
        // Multi-rep without RPE can't be estimated honestly.
        let fives = LiftLogEntry(date: date("2026-08-03"), lift: .deadlift, load: 405, reps: 5)
        XCTAssertNil(fives.compE1RM)
    }

    func testCleanSingleWithRPEUsesTable() {
        // Crisp single @9 → 96% → e1RM above the bar weight.
        let e = LiftLogEntry(date: date("2026-08-03"), lift: .squat, load: 405, reps: 1,
                             rpe: 9, cleanSingle: true)
        XCTAssertEqual(e.compE1RM!, 405 / 0.96, accuracy: 0.01)
    }

    // MARK: - persistence

    func testOldClientWithoutLogsDecodesEmpty() throws {
        let json = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","name":"Old","unit":"lb",
        "maxes":{"squat":500,"bench":300,"deadlift":550},
        "setupPhase":"full","setupWeeks":12,"fiveDay":false}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let c = try dec.decode(Client.self, from: Data(json.utf8))
        XCTAssertTrue(c.logs.isEmpty)
    }

    func testLogsRoundTrip() throws {
        var c = Client(name: "RT")
        c.logs = [LiftLogEntry(date: date("2026-08-01"), lift: .bench,
                               exerciseName: "Spoto Press", loadMod: 0.93,
                               load: 225, reps: 3, rpe: 8.5, cleanSingle: false,
                               prescribedPct: 81, prescribedRPE: 8,
                               weekNum: 4, note: "moved fast")]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let round = try dec.decode(Client.self, from: enc.encode(c))
        XCTAssertEqual(round.logs.count, 1)
        let e = round.logs[0]
        XCTAssertEqual(e.load, 225)
        XCTAssertEqual(e.rpe, 8.5)
        XCTAssertEqual(e.loadMod, 0.93)
        XCTAssertEqual(e.prescribedRPE, 8)
        XCTAssertEqual(e.weekNum, 4)
        XCTAssertEqual(e.note, "moved fast")
    }

    func testUnitConversionRoundTripsLosslessly() {
        let e = LiftLogEntry(date: date("2026-08-01"), lift: .squat, load: 405, reps: 1)
        let kg = e.converted(from: .lb, to: .kg)
        XCTAssertEqual(kg.load, 405 / Maxes.lbPerKg, accuracy: 1e-9)
        let back = kg.converted(from: .kg, to: .lb)
        XCTAssertEqual(back.load, 405, accuracy: 1e-9)
    }

    // MARK: - block-over-block verdicts

    /// 12-week factory prep, day one 2026-01-05: acc wks 1-4, deload wk 5,
    /// trans wks 6-9, real 10-11, meet 12.
    private func fixture() -> (Program, Date) {
        (Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib),
         date("2026-01-05"))
    }

    private func entry(_ day: String, _ lift: LiftPool, _ load: Double,
                       _ reps: Int, _ rpe: Double?,
                       prescribed: Double? = nil) -> LiftLogEntry {
        LiftLogEntry(date: date(day), lift: lift, load: load, reps: reps, rpe: rpe,
                     prescribedRPE: prescribed)
    }

    func testBlockOverBlockUp() {
        let (p, start) = fixture()
        // Acc (Jan 5 - Feb 1): two squat points, best e1RM 405/0.84 ≈ 482.
        // Trans (Feb 9 - Mar 8): two points, best 425/0.86 ≈ 494 → up ~2.5%.
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8),
            entry("2026-01-21", .squat, 405, 4, 8),
            entry("2026-02-11", .squat, 420, 3, 8),
            entry("2026-02-25", .squat, 425, 3, 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertEqual(t.blockBests.count, 2)
        guard case .up(let pct) = t.verdict else { return XCTFail("expected up, got \(t.verdict)") }
        XCTAssertEqual(pct, ((425 / 0.86) - (405 / 0.84)) / (405 / 0.84) * 100, accuracy: 0.01)
        XCTAssertFalse(t.checkIn)
    }

    func testBlockOverBlockDownFiresCheckIn() {
        let (p, start) = fixture()
        let logs = [
            entry("2026-01-07", .bench, 240, 4, 8),
            entry("2026-01-21", .bench, 245, 4, 8),
            entry("2026-02-11", .bench, 225, 3, 8),
            entry("2026-02-25", .bench, 228, 3, 8),
        ]
        let t = Trends.compute(lift: .bench, logs: logs, program: p, startDate: start)
        guard case .down = t.verdict else { return XCTFail("expected down, got \(t.verdict)") }
        XCTAssertTrue(t.checkIn, "e1RM down across a block → whole-picture check-in")
    }

    func testSinglePointBlocksAreInsufficient() {
        let (p, start) = fixture()
        // One point per block: a bad day isn't a trend.
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8),
            entry("2026-02-11", .squat, 380, 3, 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        guard case .insufficient = t.verdict else { return XCTFail("got \(t.verdict)") }
        XCTAssertFalse(t.checkIn)
    }

    func testDeloadAndMeetPointsExcludedFromBlocks() {
        let (p, start) = fixture()
        // Week 5 is the deload (Feb 2-8): a light single logged there must not
        // create or poison a block best.
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8),
            entry("2026-01-21", .squat, 405, 4, 8),
            entry("2026-02-04", .squat, 315, 1, 7),   // deload week — ignored
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertEqual(t.blockBests.count, 1, "only the acc block has points")
        XCTAssertEqual(t.blockBests[0].count, 2)
        // The deload point still exists in the raw series (chart shows it).
        XCTAssertEqual(t.points.count, 3)
    }

    func testEntriesOutsideProgramDatesIgnoredForBlocks() {
        let (p, start) = fixture()
        let logs = [
            entry("2025-11-01", .squat, 390, 4, 8),   // before day one
            entry("2026-01-07", .squat, 400, 4, 8),
            entry("2026-01-21", .squat, 405, 4, 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertEqual(t.blockBests.count, 1)
        XCTAssertEqual(t.blockBests[0].count, 2, "pre-program point charts but doesn't bucket")
        XCTAssertEqual(t.points.count, 3)
    }

    // MARK: - RPE drift + stall doctrine

    func testRPEDriftDetected() {
        let (p, start) = fixture()
        // Flat-ish e1RM but last three sets arrive a full point hot.
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8, prescribed: 8),
            entry("2026-01-14", .squat, 400, 4, 9, prescribed: 8),
            entry("2026-01-21", .squat, 400, 4, 9, prescribed: 8),
            entry("2026-01-28", .squat, 400, 4, 9, prescribed: 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertEqual(t.rpeDrift!, 1.0, accuracy: 0.001)
        XCTAssertTrue(t.checkIn, "strong drift alone (≥ +1) prompts the conversation")
    }

    func testNoDriftWithoutPrescribedValues() {
        let (p, start) = fixture()
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 9),
            entry("2026-01-14", .squat, 400, 4, 9),
            entry("2026-01-21", .squat, 400, 4, 9),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertNil(t.rpeDrift, "manual entries with no prescription can't drift")
        XCTAssertFalse(t.checkIn)
    }

    func testCleanSinglesExcludedFromDrift() {
        let (p, start) = fixture()
        var single = entry("2026-01-10", .squat, 445, 1, 9.5, prescribed: 8)
        single.cleanSingle = true
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8, prescribed: 8),
            single,
            entry("2026-01-14", .squat, 400, 4, 8, prescribed: 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertNil(t.rpeDrift, "two paired working sets — singles don't count toward drift")
    }

    // MARK: - review fixes

    func testRPEBelowTableFloorFallsBackToSinglesFloor() {
        // Reporting an easy RPE must never yield less than reporting none.
        let single = LiftLogEntry(date: date("2026-08-03"), lift: .deadlift,
                                  load: 500, reps: 1, rpe: 6)
        XCTAssertEqual(single.compE1RM, 500, "single @6: table floor missed, stands as itself")
        let fives = LiftLogEntry(date: date("2026-08-03"), lift: .deadlift,
                                 load: 405, reps: 5, rpe: 6)
        XCTAssertNil(fives.compE1RM, "multi-rep below the table floor still can't be estimated")
    }

    func testUnknownModifierVariationNeverNormalizes() {
        // loadMod 0 = manual variation with unknown modifier: logged, no point.
        let e = LiftLogEntry(date: date("2026-08-03"), lift: .squat,
                             exerciseName: "Pause Squat", loadMod: 0,
                             load: 300, reps: 1, rpe: 9)
        XCTAssertNil(e.compE1RM)
        XCTAssertTrue(e.isVariation)
    }

    func testVariationPointsExcludedFromVerdict() {
        let (p, start) = fixture()
        // Acc best comes through a Spoto modifier (0.93) — inflated estimate.
        // Verdict must ignore it: only one comp point per block → insufficient.
        let spoto = LiftLogEntry(date: date("2026-01-14"), lift: .bench,
                                 exerciseName: "Spoto Press", loadMod: 0.93,
                                 load: 240, reps: 4, rpe: 8)
        let logs = [
            entry("2026-01-07", .bench, 240, 4, 8),
            spoto,
            entry("2026-02-11", .bench, 245, 3, 8),
        ]
        let t = Trends.compute(lift: .bench, logs: logs, program: p, startDate: start)
        guard case .insufficient = t.verdict else { return XCTFail("got \(t.verdict)") }
        XCTAssertEqual(t.blockBests.first?.count, 1, "block bests count comp points only")
        XCTAssertEqual(t.points.count, 3, "chart still shows the variation point")
    }

    func testDeloadEntriesExcludedFromDrift() {
        let (p, start) = fixture()
        // Three deload-week sets (Feb 2-8) arriving a full point hot: normal
        // recovery feel, never a stall signal.
        let logs = [
            entry("2026-02-02", .squat, 250, 5, 7, prescribed: 6),
            entry("2026-02-04", .squat, 250, 5, 7, prescribed: 6),
            entry("2026-02-06", .squat, 250, 5, 7, prescribed: 6),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertNil(t.rpeDrift, "deload sets don't pair")
        XCTAssertFalse(t.checkIn, "a planned recovery week must not fire the check-in")
    }

    func testPreProgramEntriesExcludedFromDrift() {
        let (p, start) = fixture()
        // Stale sets from before day one can't masquerade as a current signal.
        let logs = [
            entry("2025-11-01", .squat, 400, 4, 9, prescribed: 8),
            entry("2025-11-08", .squat, 400, 4, 9, prescribed: 8),
            entry("2025-11-15", .squat, 400, 4, 9, prescribed: 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: p, startDate: start)
        XCTAssertNil(t.rpeDrift)
        XCTAssertFalse(t.checkIn)
    }

    func testNoProgramStillCharts() {
        let logs = [
            entry("2026-01-07", .squat, 400, 4, 8),
            entry("2026-01-21", .squat, 405, 4, 8),
        ]
        let t = Trends.compute(lift: .squat, logs: logs, program: nil, startDate: nil)
        XCTAssertEqual(t.points.count, 2)
        XCTAssertTrue(t.blockBests.isEmpty)
        guard case .insufficient = t.verdict else { return XCTFail() }
    }
}
