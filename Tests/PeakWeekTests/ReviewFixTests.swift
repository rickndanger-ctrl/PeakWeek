import XCTest
@testable import PeakWeek

/// Regression tests for confirmed findings from the adversarial review.
final class ReviewFixTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()
    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)
    var cal: Calendar { Calendar.current }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 10))!

    func makeClient(review: Bool) -> Client {
        var c = Client(name: "Test", unit: .lb, maxes: maxes)
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        c.startDate = monday
        c.delivery.autoSend = true
        c.delivery.requireReview = review
        c.delivery.recipient = "+15550100000"
        return c
    }

    // MARK: critical — queued weeks must not re-queue

    func testQueuedWeekReportsAlreadyQueued() {
        let c = makeClient(review: true)
        let stamp = c.program!.createdAt
        let queued = SendRecord(clientID: c.id, clientName: c.name, weekNum: 1,
                                date: date(2026, 8, 9, 18), method: .messages,
                                status: .queued, programStamp: stamp)
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 10, 9), startDate: c.startDate,
                                          program: c.program, prefs: c.delivery, records: [queued])
        XCTAssertEqual(due?.weekNum, 1)
        XCTAssertEqual(due?.alreadyQueued, true, "pass must know week 1 is already queued")
    }

    // MARK: major — program regeneration resets delivery bookkeeping

    func testOldProgramRecordsDoNotSuppressNewProgram() {
        var c = makeClient(review: false)
        let oldStamp = c.program!.createdAt
        let sentOld = SendRecord(clientID: c.id, clientName: c.name, weekNum: 1,
                                 date: date(2026, 8, 9, 18), method: .messages,
                                 status: .sent, programStamp: oldStamp)
        // Regenerate: new program, new createdAt.
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        XCTAssertNotEqual(c.program!.createdAt, oldStamp)
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 10, 9), startDate: c.startDate,
                                          program: c.program, prefs: c.delivery, records: [sentOld])
        XCTAssertEqual(due?.weekNum, 1, "week 1 of the NEW program is due despite old record")
    }

    func testLegacyStamplessRecordsStillSuppress() {
        let c = makeClient(review: false)
        let legacy = SendRecord(clientID: c.id, clientName: c.name, weekNum: 1,
                                date: date(2026, 8, 9, 18), method: .messages,
                                status: .sent, programStamp: nil)
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 10, 9), startDate: c.startDate,
                                          program: c.program, prefs: c.delivery, records: [legacy])
        XCTAssertNil(due, "stamp-less legacy records keep suppressing (no surprise resends)")
    }

    // MARK: minor — invalid prefs never crash schedule math

    func testSendMomentClampsInvalidPrefs() {
        var p = DeliveryPrefs()
        p.weekday = 99
        p.hour = -3
        // Must not crash; clamps into range.
        let m = DeliverySchedule.sendMoment(startDate: monday, weekNum: 1, prefs: p)
        XCTAssertLessThanOrEqual(m, monday)
        p.weekday = 0; p.hour = 40
        _ = DeliverySchedule.sendMoment(startDate: monday, weekNum: 1, prefs: p)
    }

    // MARK: major — kg attempts keep half-unit precision in exports

    func testMeetExportKeepsHalfKilos() {
        var c = Client(name: "Test", unit: .kg, maxes: Maxes(squat: 250, bench: 150, deadlift: 280))
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let text = Engine.weekToText(client: c, program: c.program!,
                                     week: c.program!.weeks.last!, library: lib)
        // 250 * 0.91 = 227.5 — must not print as 227
        XCTAssertTrue(text.contains("open 227.5"), "half-kilo attempts survive export: \(text.split(separator: "\n").first(where: { $0.contains("Squat: open") }) ?? "")")
    }

    // MARK: major — export shows the % the lifter actually trains at

    func testExportShowsOffsetAdjustedPercent() {
        var c = Client(name: "Test", unit: .lb, maxes: maxes)
        c.settings.perLift = ["deadlift": LiftSettings(intensityOffset: -2.5)]
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let text = Engine.weekToText(client: c, program: c.program!,
                                     week: c.program!.weeks[0], library: lib)
        XCTAssertTrue(text.contains("Competition Deadlift — 4x6 @ 64.5% → 320 lb"),
                      "displayed %% includes the offset that the load uses")
        XCTAssertTrue(text.contains("Competition Squat — 4x6 @ 67% → 270 lb"),
                      "unmodified lifts unchanged")
    }

    // MARK: engine-side clamps guard half-typed UI values

    func testAbsurdOverridesAreClampedAtUse() {
        var p = AttemptProfile()
        p.opener = 9        // half-typed "95"
        let a = Engine.attempts(max: 405, unit: .lb, profile: p)
        XCTAssertEqual(a.opener, Engine.roundLoad(405 * 0.80, unit: .lb),
                       "absurd low override clamps to 80%")
        var s = ClientSettings()
        s.perLift = ["squat": LiftSettings(trainingMaxPct: 5, intensityOffset: 400)]
        let program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let load = Engine.slotLoad(program.weeks[0].days[0].slots[0],
                                   maxes: maxes, unit: .lb, library: lib, settings: s)
        // tm clamps to 50, offset to +15: 405*0.5*0.82 = 166.05 -> 165
        XCTAssertEqual(load, 165)
    }
}
