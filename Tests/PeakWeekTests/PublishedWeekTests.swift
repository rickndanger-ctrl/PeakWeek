import XCTest
@testable import PeakWeek

/// The structured week publisher feeding the client app. One week only —
/// never the program — and prefill numbers must match what the coach's own
/// renderers compute.
final class PublishedWeekTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()

    private func makeClient() -> Client {
        var c = Client(name: "Pub Test",
                       maxes: Maxes(squat: 500, bench: 300, deadlift: 550))
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        c.startDate = f.date(from: "2026-08-04")!
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12,
                                        fiveDay: false, library: lib)
        return c
    }

    func testPublishesExactlyThatWeek() {
        let c = makeClient()
        let week = c.program!.weeks[0]
        let pub = Engine.weekToPublished(client: c, program: c.program!,
                                         week: week, library: lib)
        XCTAssertEqual(pub.weekNum, 1)
        XCTAssertEqual(pub.totalWeeks, 12)
        XCTAssertEqual(pub.phaseLabel, "Accumulation")
        XCTAssertEqual(pub.weeksOut, 11)
        XCTAssertEqual(pub.programStamp, c.program!.createdAt)
        XCTAssertEqual(pub.days.count, week.days.count)
        XCTAssertEqual(pub.dateRange, "Aug 4 – Aug 10")
    }

    func testLoggablesMatchCompPercentSlots() {
        let c = makeClient()
        let week = c.program!.weeks[0]
        let pub = Engine.weekToPublished(client: c, program: c.program!,
                                         week: week, library: lib)
        for (di, day) in week.days.enumerated() {
            let expected = day.slots.enumerated().filter { _, s in
                s.pct != nil && s.custom == nil
                    && [.squat, .bench, .deadlift].contains(s.pool)
            }
            XCTAssertEqual(pub.days[di].loggables.count, expected.count,
                           "day \(di): every comp %-slot is loggable, nothing else")
            // Prefill numbers match the coach's own load math.
            for (li, (si, slot)) in zip(pub.days[di].loggables.indices, expected) {
                let log = pub.days[di].loggables[li]
                XCTAssertEqual(log.slotIndex, si)
                XCTAssertEqual(log.reps, slot.reps)
                XCTAssertEqual(log.load,
                               Engine.slotLoad(slot, maxes: c.maxes, unit: c.unit,
                                               library: lib, settings: c.settings))
            }
        }
    }

    func testLinesCarryLoadsAndEffort() {
        let c = makeClient()
        let week = c.program!.weeks[0]
        let pub = Engine.weekToPublished(client: c, program: c.program!,
                                         week: week, library: lib)
        let day1 = pub.days[0]
        XCTAssertTrue(day1.lines[0].contains("→"), "main lift shows a load target")
        XCTAssertTrue(day1.lines[0].contains("RPE"), "percent work speaks RPE")
        XCTAssertTrue(day1.lines.contains { $0.contains("RIR") },
                      "accessories speak RIR")
    }

    func testRoundTripsAsJSON() throws {
        let c = makeClient()
        let pub = Engine.weekToPublished(client: c, program: c.program!,
                                         week: c.program!.weeks[0], library: lib)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let round = try dec.decode(PublishedWeek.self, from: enc.encode(pub))
        // ISO8601 drops sub-second precision — compare STABILITY (re-encoded
        // bytes identical), not Date identity.
        XCTAssertEqual(try enc.encode(round), try enc.encode(pub))
        XCTAssertEqual(round.days, pub.days)
        XCTAssertEqual(round.weekNum, pub.weekNum)
        // And no double units in display lines (the bug this test caught).
        XCTAssertFalse(pub.days[0].lines[0].contains("lb lb"))
    }
}
