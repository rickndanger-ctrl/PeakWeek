import XCTest
@testable import PeakWeek

/// Day-order preference (lifter-chosen training day sequence) and the
/// on-demand full-program send. Reordering is a pure re-sequencing: frozen
/// factory content must survive byte-identical, only day order (and therefore
/// each day's calendar date) changes. Meet week never reorders.
final class DayOrderTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()

    private func date(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: s)!
    }

    // MARK: - applyDayOrder

    func testDeadliftFirstReordersAllTrainingWeeks() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let originalWeek1 = p.weeks[0].days
        let touched = p.applyDayOrder([2, 1, 0, 3])   // DL, BP, SQ, BP2

        // Every non-meet week moves; the meet week keeps platform structure.
        XCTAssertEqual(touched, p.weeks.filter { $0.phase != .meet }.count)
        XCTAssertEqual(p.weeks[0].days[0].id, originalWeek1[2].id, "deadlift day leads")
        XCTAssertEqual(p.weeks[0].days[2].id, originalWeek1[0].id, "squat day now third")
        // Titles renumber to the NEW position — "Day 1" is the first day
        // trained; the descriptive name travels with the day.
        XCTAssertEqual(p.weeks[0].days[0].title, "Day 1 — Deadlift")
        XCTAssertEqual(p.weeks[0].days[1].title, "Day 2 — Bench")
        XCTAssertEqual(p.weeks[0].days[2].title, "Day 3 — Squat")
        XCTAssertEqual(p.weeks[0].days[3].title, "Day 4 — Bench 2")
        // Special realization titles keep their descriptive tail.
        if let heavy = p.weeks.first(where: { w in
            w.days.contains { $0.title.contains("LAST HEAVY DEADLIFT") }
        }) {
            let dl = heavy.days.first { $0.title.contains("LAST HEAVY DEADLIFT") }!
            XCTAssertTrue(dl.title.hasPrefix("Day 1"),
                          "DL-first order puts the last heavy pull on day 1: \(dl.title)")
        }

        // Pure re-sequencing: same days, same slots, nothing edited.
        XCTAssertEqual(Set(p.weeks[0].days.map(\.id)), Set(originalWeek1.map(\.id)))
        XCTAssertEqual(p.weeks[0].days[0].slots, originalWeek1[2].slots)

        // Ordering is ABSOLUTE: re-applying the SAME order is a no-op…
        XCTAssertEqual(p.applyDayOrder([2, 1, 0, 3]), 0)
        XCTAssertEqual(p.weeks[0].days[0].title, "Day 1 — Deadlift")
        // …and factory order restores factory sequence (never compounds).
        p.applyDayOrder([0, 1, 2, 3])
        XCTAssertEqual(p.weeks[0].days.map(\.id), originalWeek1.map(\.id))
        XCTAssertEqual(p.weeks[0].days[0].title, "Day 1 — Squat")
    }

    func testMeetWeekNeverReorders() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let meetDays = p.weeks.last!.days.map(\.id)
        p.applyDayOrder([2, 1, 0, 3])
        XCTAssertEqual(p.weeks.last!.days.map(\.id), meetDays,
                       "platform week structure is doctrine — primers early, rest late")
    }

    func testIdentityAndInvalidOrdersAreNoops() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let snapshot = p
        XCTAssertEqual(p.applyDayOrder([0, 1, 2, 3]), 0, "identity changes nothing")
        XCTAssertEqual(p.applyDayOrder([0, 1, 2]), 0, "wrong length rejected on 4-day weeks")
        XCTAssertEqual(p.applyDayOrder([0, 0, 1, 2]), 0, "not a permutation")
        XCTAssertEqual(p.applyDayOrder([]), 0)
        XCTAssertEqual(p.weeks.map(\.id), snapshot.weeks.map(\.id))
        XCTAssertEqual(p.weeks[0].days.map(\.id), snapshot.weeks[0].days.map(\.id))
    }

    func testFiveDayOrderInducesSubOrderOnFourDayWeeks() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: true, library: lib)
        // 5-day acc/trans weeks; realization runs 4 days. Squat-2-first order:
        let order = [4, 0, 1, 2, 3]
        p.applyDayOrder(order)
        let acc = p.weeks.first { $0.phase == .acc }!
        XCTAssertEqual(acc.days.count, 5)
        XCTAssertTrue(acc.days[0].title.hasPrefix("Day 1"),
                      "leading day renumbers to Day 1: \(acc.days[0].title)")
        XCTAssertTrue(acc.days[0].title.contains("Squat 2"),
                      "5th factory day now leads: \(acc.days[0].title)")
        // A 4-day realization week uses the induced sub-order (4 dropped):
        // [0,1,2,3] = unchanged.
        if let real = p.weeks.first(where: { $0.phase == .real && $0.days.count == 4 }) {
            XCTAssertTrue(real.days[0].title.contains("Squat"),
                          "induced order keeps squat first on 4-day weeks")
        }
    }

    func testGoldenContentSurvivesReorder() {
        // Reordering must not touch a single slot: sets, reps, pcts identical
        // as a multiset across the whole program.
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let before = p.weeks.flatMap { $0.days.flatMap(\.slots) }.sorted { $0.id.uuidString < $1.id.uuidString }
        p.applyDayOrder([3, 2, 1, 0])
        let after = p.weeks.flatMap { $0.days.flatMap(\.slots) }.sorted { $0.id.uuidString < $1.id.uuidString }
        XCTAssertEqual(before, after)
    }

    func testStaleTitlesRepairedByReapplyingSameOrder() {
        // A program saved by the pre-fix build: days moved, titles kept their
        // factory numbers ("Day 3 — Deadlift" sitting first), and — because
        // the file predates factoryIndex — no stored identity. Applying the
        // SAME order must repair the numbering in place, inferring identity
        // from the stale title numbers, WITHOUT permuting again.
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        for wi in p.weeks.indices where p.weeks[wi].phase != .meet {
            let order = [2, 1, 0, 3].filter { $0 < p.weeks[wi].days.count }
            guard order.count == p.weeks[wi].days.count else { continue }
            p.weeks[wi].days = order.map { p.weeks[wi].days[$0] }   // old buggy move
            for di in p.weeks[wi].days.indices {                    // legacy file: no identity
                p.weeks[wi].days[di].factoryIndex = nil
            }
        }
        XCTAssertTrue(p.weeks[0].days[0].title.hasPrefix("Day 3"), "stale state reproduced")
        let dlID = p.weeks[0].days[0].id

        let touched = p.applyDayOrder([2, 1, 0, 3])
        XCTAssertGreaterThan(touched, 0, "stale titles read as a difference")
        XCTAssertEqual(p.weeks[0].days[0].id, dlID, "deadlift day STAYS first — no double permute")
        XCTAssertEqual(p.weeks[0].days[0].title, "Day 1 — Deadlift")
        XCTAssertEqual(p.weeks[0].days[2].title, "Day 3 — Squat")
        XCTAssertEqual(p.weeks[0].days[0].factoryIndex, 2, "inferred identity stamped for the future")
    }

    // MARK: - projection follows day order

    func testPeakProjectionFollowsReorderedDays() {
        var p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let start = date("2026-01-05")
        let meet = date("2026-03-28")   // Saturday of week 12

        let factory = PeakProjection.compute(program: p, startDate: start, meetDate: meet)!
        let factoryDL = factory.events.first { $0.kind == .lastHeavyDeadlift }!
        let factorySQ = factory.events.first { $0.kind == .lastHeavySquat }!

        p.applyDayOrder([2, 1, 0, 3])   // deadlift day first
        let reordered = PeakProjection.compute(program: p, startDate: start, meetDate: meet)!
        let dl = reordered.events.first { $0.kind == .lastHeavyDeadlift }!
        let sq = reordered.events.first { $0.kind == .lastHeavySquat }!

        // DL moved from position 2 to 0 → two days earlier → two MORE days out.
        XCTAssertEqual(dl.daysOut, factoryDL.daysOut + 2)
        // SQ moved from position 0 to 2 → two days closer to the meet.
        XCTAssertEqual(sq.daysOut, factorySQ.daysOut - 2)
    }

    func testClientDayOrderDecodesTolerantly() throws {
        let json = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","name":"Old","unit":"lb",
        "maxes":{"squat":500,"bench":300,"deadlift":550},
        "setupPhase":"full","setupWeeks":12,"fiveDay":false}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let c = try dec.decode(Client.self, from: Data(json.utf8))
        XCTAssertNil(c.dayOrder, "absent = factory order")

        var c2 = c
        c2.dayOrder = [2, 1, 0, 3]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let round = try dec.decode(Client.self, from: enc.encode(c2))
        XCTAssertEqual(round.dayOrder, [2, 1, 0, 3])
    }

}
