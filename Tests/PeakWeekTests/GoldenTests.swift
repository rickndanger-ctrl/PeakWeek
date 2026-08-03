import XCTest
@testable import PeakWeek

/// The heavy locks: a genuine v1 file must migrate losslessly, and the
/// library-resolved builder must produce output identical to the legacy
/// index-referenced engine for EVERY week of EVERY phase.
final class GoldenTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()

    // MARK: - real v1 fixture migration

    func testGenuineV1FileMigrates() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/v1-data", withExtension: "json"))
        let raw = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let data = try dec.decode(AppData.self, from: raw)

        XCTAssertEqual(data.schemaVersion, 3)
        XCTAssertEqual(data.clients.map(\.name), ["Legacy Lifter", "Kilo Kate", "No Program Norm"])

        // Every slot gained a canonical ID resolvable in the seeded library.
        let legacy = data.clients[0]
        XCTAssertEqual(legacy.program?.weeks.count, 12)
        for week in legacy.program!.weeks {
            for day in week.days {
                for slot in day.slots where slot.custom == nil {
                    XCTAssertNotNil(slot.exerciseID, "wk\(week.num) \(day.title)")
                    XCTAssertNotNil(data.exerciseLibrary.exercise(id: slot.exerciseID!))
                }
            }
        }
        // Canonical numbers survive: W1D1 Competition Squat 4x6 @67 -> 270.
        let s = legacy.program!.weeks[0].days[0].slots[0]
        XCTAssertEqual(Engine.slotName(s, library: data.exerciseLibrary), "Competition Squat")
        XCTAssertEqual(Engine.slotLoad(s, maxes: legacy.maxes, unit: .lb,
                                       library: data.exerciseLibrary), 270)
        // kg client intact, no delivery/settings surprises.
        XCTAssertEqual(data.clients[1].unit, .kg)
        XCTAssertFalse(data.clients[1].delivery.autoSend)
        XCTAssertFalse(data.clients[1].settings.isCustomized)
        // Re-encode + re-decode is stable.
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let round = try dec.decode(AppData.self, from: enc.encode(data))
        XCTAssertEqual(round.clients, data.clients)
    }

    // MARK: - full-surface golden equality (locks every phase's numbers)

    func testLibraryBuilderIdenticalToLegacyEverywhere() {
        let client = Client(name: "Golden", unit: .lb,
                            maxes: Maxes(squat: 405, bench: 275, deadlift: 495))
        let cases: [(StartPhase, Int, Bool)] = [
            (.full, 10, false), (.full, 12, false), (.full, 12, true), (.full, 16, true),
            (.offseason, 10, false), (.acc, 5, true), (.trans, 5, false), (.real, 3, false),
        ]
        for (phase, weeks, fiveDay) in cases {
            let legacy = Engine.buildProgramLegacy(startPhase: phase, totalWeeks: weeks, fiveDay: fiveDay)
            let modern = Engine.buildProgram(startPhase: phase, totalWeeks: weeks, fiveDay: fiveDay, library: lib)
            XCTAssertEqual(legacy.weeks.count, modern.weeks.count)
            for (lw, mw) in zip(legacy.weeks, modern.weeks) {
                let lt = Engine.weekToText(client: client, program: legacy, week: lw, library: lib)
                let mt = Engine.weekToText(client: client, program: modern, week: mw, library: lib)
                XCTAssertEqual(lt, mt, "\(phase) \(weeks)wk fiveDay=\(fiveDay) week \(lw.num)")
            }
        }
    }

    // MARK: - unit conversion round-trip

    func testUnitConversionRoundTripsExactly() {
        let original = Maxes(squat: 405, bench: 275, deadlift: 495)
        let kg = original.converted(from: .lb, to: .kg)
        let back = kg.converted(from: .kg, to: .lb)
        XCTAssertEqual(back.squat, original.squat, accuracy: 1e-9)
        XCTAssertEqual(back.bench, original.bench, accuracy: 1e-9)
        XCTAssertEqual(back.deadlift, original.deadlift, accuracy: 1e-9)
        // Sanity: 405 lb ≈ 183.7 kg
        XCTAssertEqual(kg.squat, 183.7, accuracy: 0.05)
        XCTAssertEqual(original.converted(from: .lb, to: .lb), original)
    }
}
