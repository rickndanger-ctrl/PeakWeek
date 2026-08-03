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

    // MARK: - absolute phase pins
    // Mutation testing proved legacy-vs-library equality can't catch a changed
    // percentage table (both sides share it). These pins lock the actual
    // numbers of every non-acc phase. 16-wk full prep: acc 1-6, deload 7,
    // trans 8-12, realization 13-15 (3/2/1 out), meet 16.

    func testAbsolutePhasePins() {
        let client = Client(name: "Pin", unit: .lb,
                            maxes: Maxes(squat: 405, bench: 275, deadlift: 495))
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 16, fiveDay: false, library: lib)
        XCTAssertEqual(p.blocks.map(\.weeks), [6, 1, 5, 3, 1])
        func text(_ weekIdx: Int) -> String {
            Engine.weekToText(client: client, program: p, week: p.weeks[weekIdx], library: lib)
        }

        // Deload (wk7): 62% across the lifts, RPE 6.
        let deload = text(6)
        XCTAssertTrue(deload.contains("Competition Squat — 3x5 @ 62% → 250 lb · RPE 6"), deload)
        XCTAssertTrue(deload.contains("Competition Bench — 3x5 @ 62% → 170 lb · RPE 6"), deload)
        XCTAssertTrue(deload.contains("Competition Deadlift — 2x4 @ 62% → 305 lb · RPE 6"), deload)

        // Transmutation first week (t=0): 77/76/78 tops, RPE 7.5-8.
        let transFirst = text(7)
        XCTAssertTrue(transFirst.contains("Competition Squat — 4x4 @ 77% → 310 lb · RPE 7.5"), transFirst)
        XCTAssertTrue(transFirst.contains("Competition Bench — 4x4 @ 76% → 210 lb · RPE 7.5"), transFirst)
        XCTAssertTrue(transFirst.contains("Competition Deadlift — 4x3 @ 78% → 385 lb · RPE 8"), transFirst)

        // Transmutation last week (t=1): 86/85/87 tops.
        let transLast = text(11)
        XCTAssertTrue(transLast.contains("Competition Squat — 4x4 @ 86% → 350 lb · RPE 7.5"), transLast)
        XCTAssertTrue(transLast.contains("Competition Bench — 4x4 @ 85% → 235 lb · RPE 7.5"), transLast)
        XCTAssertTrue(transLast.contains("Competition Deadlift — 4x3 @ 87% → 430 lb · RPE 8"), transLast)

        // Realization 3 out: 87/86/88 triples/doubles.
        let real3 = text(12)
        XCTAssertTrue(real3.contains("Competition Squat — 3x3 @ 87% → 350 lb · RPE 8"), real3)
        XCTAssertTrue(real3.contains("Competition Bench — 3x3 @ 86% → 235 lb · RPE 8"), real3)
        XCTAssertTrue(real3.contains("Competition Deadlift — 3x2 @ 88% → 435 lb · RPE 8"), real3)

        // Realization 2 out: heavy doubles + LAST HEAVY DEADLIFT @92.
        let real2 = text(13)
        XCTAssertTrue(real2.contains("Competition Squat — 2x2 @ 90% → 365 lb · RPE 8.5"), real2)
        XCTAssertTrue(real2.contains("LAST HEAVY DEADLIFT"), real2)
        XCTAssertTrue(real2.contains("Competition Deadlift — 1x1 @ 92% → 455 lb · RPE 8.5"), real2)

        // Realization 1 out: openers @92.
        let real1 = text(14)
        XCTAssertTrue(real1.contains("OPENER"), real1)
        // 405 × .92 = 372.6 → 375 (the 91% ATTEMPT opener is 370 — different number!)
        XCTAssertTrue(real1.contains("Competition Squat — 1x1 @ 92% → 375 lb · RPE 8"), real1)
        XCTAssertTrue(real1.contains("Competition Bench — 1x1 @ 92% → 255 lb · RPE 8"), real1)

        // Meet week: 60/60/55 technique primer only.
        let meet = text(15)
        XCTAssertTrue(meet.contains("Competition Squat — 2x2 @ 60% → 245 lb · RPE 5"), meet)
        XCTAssertTrue(meet.contains("Competition Deadlift — 1x2 @ 55% → 270 lb · RPE 5"), meet)
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
