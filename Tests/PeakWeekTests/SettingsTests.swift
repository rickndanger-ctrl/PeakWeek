import XCTest
@testable import PeakWeek

final class SettingsTests: XCTestCase {

    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)
    let lib = ExerciseLibrary.seeded()

    // MARK: - attempt profiles

    func testDefaultProfileMatchesEngineExactly() {
        let plain = Engine.attempts(max: 405, unit: .lb)
        let profiled = Engine.attempts(max: 405, unit: .lb, profile: AttemptProfile())
        XCTAssertEqual(plain.opener, profiled.opener)
        XCTAssertEqual(plain.second, profiled.second)
        XCTAssertEqual(plain.third, profiled.third)
        XCTAssertEqual(plain.opener, 370)
        XCTAssertEqual(plain.second, 395)
        XCTAssertEqual(plain.third, 410)
    }

    func testRiskPresets() {
        var p = AttemptProfile()
        p.risk = .conservative
        var a = Engine.attempts(max: 405, unit: .lb, profile: p)
        XCTAssertEqual(a.opener, 360)   // 405 * .895 = 362.475 -> 360
        XCTAssertEqual(a.third, 405)    // 100% of gym max
        p.risk = .aggressive
        a = Engine.attempts(max: 405, unit: .lb, profile: p)
        XCTAssertEqual(a.opener, 375)   // 405 * .925 = 374.6 -> 375
        XCTAssertEqual(a.third, 420)    // 405 * 1.04 = 421.2 -> 420
    }

    func testExplicitOverridesBeatPreset() {
        var p = AttemptProfile()
        p.risk = .aggressive
        p.third = 101.5                 // pull the third back to standard
        let a = Engine.attempts(max: 405, unit: .lb, profile: p)
        XCTAssertEqual(a.opener, 375, "opener still follows aggressive preset")
        XCTAssertEqual(a.third, 410, "explicit third override wins")
    }

    // MARK: - per-lift settings

    func testTrainingMaxScalesLoads() {
        var settings = ClientSettings()
        settings.perLift = ["squat": LiftSettings(trainingMaxPct: 95)]
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let squat = p.weeks[0].days[0].slots[0]     // 4x6 @ 67%
        // 405 * 0.95 * 0.67 = 257.78 -> 260
        XCTAssertEqual(Engine.slotLoad(squat, maxes: maxes, unit: .lb, library: lib,
                                       settings: settings), 260)
        // Bench untouched: 275 * 0.65 = 178.75 -> 180
        let bench = p.weeks[0].days[1].slots[0]
        XCTAssertEqual(Engine.slotLoad(bench, maxes: maxes, unit: .lb, library: lib,
                                       settings: settings), 180)
    }

    func testIntensityOffsetShiftsPercent() {
        var settings = ClientSettings()
        settings.perLift = ["deadlift": LiftSettings(intensityOffset: -2.5)]
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let dl = p.weeks[0].days[2].slots[0]        // 4x6 @ 67%
        // 495 * (67 - 2.5)/100 = 319.3 -> 320  (vs 330 unmodified)
        XCTAssertEqual(Engine.slotLoad(dl, maxes: maxes, unit: .lb, library: lib,
                                       settings: settings), 320)
    }

    func testNilSettingsIdenticalToNoSettings() {
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        for day in p.weeks[0].days {
            for slot in day.slots {
                XCTAssertEqual(
                    Engine.slotLoad(slot, maxes: maxes, unit: .lb, library: lib),
                    Engine.slotLoad(slot, maxes: maxes, unit: .lb, library: lib,
                                    settings: ClientSettings()),
                    "empty settings never change a load")
            }
        }
    }

    // MARK: - weeks-out in export

    func testWeeksOutInExportHeader() {
        let client = Client(name: "Test", unit: .lb, maxes: maxes)
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let w1 = Engine.weekToText(client: client, program: p, week: p.weeks[0], library: lib)
        XCTAssertTrue(w1.contains("WEEK 1 of 12 — ACCUMULATION — 11 WKS OUT"), "got: \(w1.prefix(80))")
        let meet = Engine.weekToText(client: client, program: p, week: p.weeks[11], library: lib)
        XCTAssertTrue(meet.contains("MEET WEEK — MEET WEEK IS HERE"))
        // Off-season programs have no meet coordinate
        let off = Engine.buildProgram(startPhase: .offseason, totalWeeks: 10, fiveDay: false, library: lib)
        let offText = Engine.weekToText(client: client, program: off, week: off.weeks[0], library: lib)
        XCTAssertFalse(offText.contains("OUT"))
    }

    // MARK: - customization flag & decode tolerance

    func testIsCustomizedFlag() {
        var s = ClientSettings()
        XCTAssertFalse(s.isCustomized)
        s.notes = "USAPL"
        XCTAssertTrue(s.isCustomized)
        s = ClientSettings()
        s.perLift = ["squat": LiftSettings(trainingMaxPct: 95)]
        XCTAssertTrue(s.isCustomized)
        s = ClientSettings()
        s.attempts = { var a = AttemptProfile(); a.risk = .aggressive; return a }()
        XCTAssertTrue(s.isCustomized)
    }

    func testClientWithoutSettingsDecodes() throws {
        let json = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","name":"Old","unit":"lb",
        "maxes":{"squat":500,"bench":300,"deadlift":550},
        "setupPhase":"full","setupWeeks":12,"fiveDay":false}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let c = try dec.decode(Client.self, from: Data(json.utf8))
        XCTAssertFalse(c.settings.isCustomized)
        XCTAssertNil(c.meetDate)
    }
}
