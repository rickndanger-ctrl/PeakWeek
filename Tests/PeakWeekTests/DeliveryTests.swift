import XCTest
@testable import PeakWeek

final class DeliveryTests: XCTestCase {

    var cal: Calendar { Calendar.current }
    let lib = ExerciseLibrary.seeded()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // 2026-08-10 is a Monday.
    let monday = { () -> Date in
        Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 10))!
    }()

    func makeClient(autoSend: Bool = true, review: Bool = false,
                    weekday: Int = 1, hour: Int = 18) -> Client {
        var c = Client(name: "Test", unit: .lb,
                       maxes: Maxes(squat: 405, bench: 275, deadlift: 495))
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        c.startDate = monday
        c.delivery.autoSend = autoSend
        c.delivery.requireReview = review
        c.delivery.recipient = "+15550100000"
        c.delivery.weekday = weekday
        c.delivery.hour = hour
        return c
    }

    // MARK: - schedule math

    func testMondayNormalization() {
        let wednesday = date(2026, 8, 12)
        XCTAssertEqual(DeliverySchedule.mondayOfWeek(containing: wednesday), date(2026, 8, 10))
        XCTAssertEqual(DeliverySchedule.mondayOfWeek(containing: date(2026, 8, 10)), date(2026, 8, 10))
        // Sunday belongs to the week that STARTED the previous Monday
        XCTAssertEqual(DeliverySchedule.mondayOfWeek(containing: date(2026, 8, 16)), date(2026, 8, 10))
    }

    func testWeekStartProgression() {
        XCTAssertEqual(DeliverySchedule.weekStart(startDate: monday, weekNum: 1), date(2026, 8, 10))
        XCTAssertEqual(DeliverySchedule.weekStart(startDate: monday, weekNum: 3), date(2026, 8, 24))
    }

    func testSendMomentSundayBeforeWeek() {
        // Sunday 18:00 before week 1 (Mon Aug 10) = Aug 9, 18:00
        let prefs = { var p = DeliveryPrefs(); p.weekday = 1; p.hour = 18; return p }()
        XCTAssertEqual(DeliverySchedule.sendMoment(startDate: monday, weekNum: 1, prefs: prefs),
                       date(2026, 8, 9, 18))
    }

    func testSendMomentMondayMorningOfWeek() {
        let prefs = { var p = DeliveryPrefs(); p.weekday = 2; p.hour = 6; return p }()
        XCTAssertEqual(DeliverySchedule.sendMoment(startDate: monday, weekNum: 2, prefs: prefs),
                       date(2026, 8, 17, 6))
    }

    func testSendMomentFridayBeforeWeek() {
        // Friday (weekday 6) 20:00 before week 1 (Mon Aug 10) = Aug 7, 20:00
        let prefs = { var p = DeliveryPrefs(); p.weekday = 6; p.hour = 20; return p }()
        XCTAssertEqual(DeliverySchedule.sendMoment(startDate: monday, weekNum: 1, prefs: prefs),
                       date(2026, 8, 7, 20))
    }

    // MARK: - due computation & catch-up policy

    func testNothingDueBeforeMoment() {
        let c = makeClient()
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 9, 17), startDate: c.startDate,
                                           program: c.program, prefs: c.delivery, records: [])
        XCTAssertNil(due)
    }

    func testWeek1DueAtMoment() {
        let c = makeClient()
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 9, 18), startDate: c.startDate,
                                           program: c.program, prefs: c.delivery, records: [])
        XCTAssertEqual(due?.weekNum, 1)
        XCTAssertEqual(due?.supersededWeeks, [])
    }

    func testCatchUpSendsOnlyLatestWeek() {
        // App was closed for 3 weeks: weeks 1-3 all due -> send 3, skip 1-2.
        let c = makeClient()
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 24, 12), startDate: c.startDate,
                                           program: c.program, prefs: c.delivery, records: [])
        XCTAssertEqual(due?.weekNum, 3)
        XCTAssertEqual(due?.supersededWeeks, [1, 2])
    }

    func testTerminalRecordsPreventResend() {
        let c = makeClient()
        let sent = SendRecord(clientID: c.id, clientName: c.name, weekNum: 1,
                              date: date(2026, 8, 9, 18), method: .messages, status: .sent)
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 10, 9), startDate: c.startDate,
                                           program: c.program, prefs: c.delivery, records: [sent])
        XCTAssertNil(due, "already-sent week must not re-send")
    }

    func testQueuedRecordDoesNotSatisfyDueWeek() {
        let c = makeClient()
        let queued = SendRecord(clientID: c.id, clientName: c.name, weekNum: 1,
                                date: date(2026, 8, 9, 18), method: .messages, status: .queued)
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 10, 9), startDate: c.startDate,
                                           program: c.program, prefs: c.delivery, records: [queued])
        XCTAssertEqual(due?.weekNum, 1, "queued weeks stay due until approved or dismissed")
    }

    func testDisabledOrUnconfiguredNeverDue() {
        var off = makeClient(); off.delivery.autoSend = false
        XCTAssertNil(DeliverySchedule.dueSend(now: .distantFuture, startDate: off.startDate,
                                              program: off.program, prefs: off.delivery, records: []))
        var noRecipient = makeClient(); noRecipient.delivery.recipient = "  "
        XCTAssertNil(DeliverySchedule.dueSend(now: .distantFuture, startDate: noRecipient.startDate,
                                              program: noRecipient.program,
                                              prefs: noRecipient.delivery, records: []))
        let noStart = makeClient()
        XCTAssertNil(DeliverySchedule.dueSend(now: .distantFuture, startDate: nil,
                                              program: noStart.program,
                                              prefs: noStart.delivery, records: []))
    }

    // MARK: - mid-prep onboarding: firstSendWeek

    func testFirstSendWeekSkipsEarlierWeeksEntirely() {
        var c = makeClient()
        c.delivery.firstSendWeek = 5
        // Deep into the program: weeks 1-6 all past their send moments.
        let due = DeliverySchedule.dueSend(now: date(2026, 9, 14, 12), startDate: c.startDate,
                                          program: c.program, prefs: c.delivery, records: [])
        XCTAssertEqual(due?.weekNum, 6, "latest due week at/after the start")
        XCTAssertEqual(due?.supersededWeeks, [5], "week 5 superseded; weeks 1-4 NEVER appear")
    }

    func testFirstSendWeekNilMeansFromWeekOne() {
        let c = makeClient()
        let due = DeliverySchedule.dueSend(now: date(2026, 8, 9, 18), startDate: c.startDate,
                                          program: c.program, prefs: c.delivery, records: [])
        XCTAssertEqual(due?.weekNum, 1)
    }

    // MARK: - calendar position + next planned send

    func testCurrentWeek() {
        let c = makeClient()
        XCTAssertEqual(DeliverySchedule.currentWeek(now: date(2026, 8, 12), startDate: monday,
                                                    program: c.program!), 1)
        XCTAssertEqual(DeliverySchedule.currentWeek(now: date(2026, 8, 24), startDate: monday,
                                                    program: c.program!), 3)
        XCTAssertNil(DeliverySchedule.currentWeek(now: date(2026, 8, 2), startDate: monday,
                                                  program: c.program!), "before the program")
        XCTAssertNil(DeliverySchedule.currentWeek(now: date(2026, 12, 1), startDate: monday,
                                                  program: c.program!), "after the program")
    }

    func testNextPlannedSend() {
        let c = makeClient()   // Sunday 18:00 prefs
        let next = DeliverySchedule.nextPlannedSend(now: date(2026, 8, 10, 9), startDate: monday,
                                                    program: c.program, prefs: c.delivery, records: [])
        // Week 1's moment (Aug 9 18:00) has passed; next FUTURE moment is week 2's.
        XCTAssertEqual(next?.week, 2)
        XCTAssertEqual(next?.moment, date(2026, 8, 16, 18))
        // firstSendWeek pushes the next planned send forward.
        var prefs = c.delivery
        prefs.firstSendWeek = 6
        let next6 = DeliverySchedule.nextPlannedSend(now: date(2026, 8, 10, 9), startDate: monday,
                                                     program: c.program, prefs: prefs, records: [])
        XCTAssertEqual(next6?.week, 6)
    }

    // MARK: - export shows the calendar week being sent

    func testExportCarriesWeekDateRange() {
        var c = makeClient()
        c.startDate = monday
        let text = Engine.weekToText(client: c, program: c.program!, week: c.program!.weeks[0],
                                     library: lib)
        XCTAssertTrue(text.contains("Week of Mon Aug 10 – Sun Aug 16"), String(text.prefix(120)))
        // Without a start date the line is simply absent.
        var noDate = c
        noDate.startDate = nil
        let plain = Engine.weekToText(client: noDate, program: noDate.program!,
                                      week: noDate.program!.weeks[0], library: lib)
        XCTAssertFalse(plain.contains("Week of "))
    }

    // MARK: - bridge scripts (dry run — nothing executes)

    func testMessagesScriptShape() {
        let s = SendBridge.messagesScript(recipient: "+1555", text: "hi \"champ\"",
                                          attachment: URL(fileURLWithPath: "/tmp/w.pdf"))
        XCTAssertTrue(s.contains("tell application \"Messages\""))
        XCTAssertTrue(s.contains("participant \"+1555\""))
        XCTAssertTrue(s.contains("send \"hi \\\"champ\\\"\""), "quotes are escaped")
        XCTAssertTrue(s.contains("POSIX file \"/tmp/w.pdf\""))
    }

    func testMailScriptShape() {
        let s = SendBridge.mailScript(recipient: "a@b.c", subject: "Week 1",
                                      body: "line", attachment: nil)
        XCTAssertTrue(s.contains("tell application \"Mail\""))
        XCTAssertTrue(s.contains("{address:\"a@b.c\"}"))
        XCTAssertFalse(s.contains("attachment"), "no attachment block when nil")
        XCTAssertTrue(s.contains("send newMessage"))
    }

    func testSendDryRunCapture() {
        var captured: [String] = []
        SendBridge.dryRunCapture = { captured.append($0) }
        defer { SendBridge.dryRunCapture = nil }
        let r = SendBridge.send(via: .messages, to: "+1555", subject: "s", text: "t", attachment: nil)
        if case .failure = r { XCTFail("dry run must succeed") }
        XCTAssertEqual(captured.count, 1)
        XCTAssertTrue(captured[0].contains("Messages"))
    }

    func testEmptyRecipientFails() {
        let r = SendBridge.send(via: .mail, to: "  ", subject: "s", text: "t", attachment: nil)
        guard case .failure(.emptyRecipient) = r else { return XCTFail("expected emptyRecipient") }
    }

    // MARK: - migration: v1 data.json (no delivery fields) still decodes

    func testV1DataStillDecodes() throws {
        let v1 = """
        {"clients":[{"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","name":"Old Client",
        "unit":"lb","maxes":{"squat":500,"bench":300,"deadlift":550},
        "setupPhase":"full","setupWeeks":12,"fiveDay":false}]}
        """
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let data = try dec.decode(AppData.self, from: Data(v1.utf8))
        XCTAssertEqual(data.clients.count, 1)
        let c = data.clients[0]
        XCTAssertEqual(c.name, "Old Client")
        XCTAssertNil(c.startDate)
        XCTAssertFalse(c.delivery.autoSend, "delivery defaults applied")
        XCTAssertTrue(c.delivery.requireReview)
        XCTAssertTrue(data.sendLog.isEmpty)
        XCTAssertEqual(data.schemaVersion, 3, "decoding migrates v1 → current schema")
        let enc = JSONEncoder()
        let out = String(decoding: try enc.encode(data), as: UTF8.self)
        XCTAssertTrue(out.contains("\"schemaVersion\":3"), "current stamp persists on next save")
    }
}
