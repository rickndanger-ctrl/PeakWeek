import XCTest
@testable import PeakWeek

/// The delivery loop's failure paths. Written after a real client (a paying
/// lifter with a paired phone) started depending on the weekly send, and an
/// audit found every failure mode was silent AND permanent.
///
/// The contract under test:
///   1. A failed text still publishes the week to her phone.
///   2. A queued (unapproved) week never publishes.
///   3. Nothing fails quietly — the coach is notified and the badge counts it.
final class DeliveryFailureTests: XCTestCase {

    var cal: Calendar { Calendar.current }
    let lib = ExerciseLibrary.seeded()

    /// 2026-08-10 is a Monday.
    let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 10))!

    /// Every publish attempt the store made: (clientID, weekNum).
    var published: [(UUID, Int)] = []
    /// Every notification the store posted: (title, body).
    var notes: [(String, String)] = []
    /// What the fake transport should return.
    var transport: Result<Void, SendError> = .success(())

    override func setUp() {
        super.setUp()
        published = []; notes = []; transport = .success(())
        SendBridge.dryRunCapture = { _ in }
        SendBridge.dryRunOutcome = .success(())
        Notifier.capture = { [weak self] title, body in self?.notes.append((title, body)) }
        SyncService.publishCapture = { [weak self] id, week, _ in
            self?.published.append((id, week))
            return true
        }
    }

    override func tearDown() {
        SendBridge.dryRunCapture = nil
        SendBridge.dryRunOutcome = .success(())
        Notifier.capture = nil
        SyncService.publishCapture = nil
        super.tearDown()
    }

    func makeStore(review: Bool = false) -> (AppStore, Client) {
        let store = AppStore(inMemory: true)
        var c = Client(name: "Lauri", unit: .lb,
                       maxes: Maxes(squat: 285, bench: 155, deadlift: 335))
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12,
                                        fiveDay: false, library: lib)
        c.startDate = monday
        c.delivery.autoSend = true
        c.delivery.requireReview = review
        c.delivery.recipient = "+15550100000"
        c.delivery.weekday = 2          // Monday
        c.delivery.hour = 9
        store.data.clients = [c]
        return (store, c)
    }

    /// The reconciler publishes on a detached Task; give it a turn to land.
    func settle() {
        let done = expectation(description: "async publish settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    // MARK: - the headline: a broken text must not strand her phone

    func testPublishHappensEvenWhenTheMessageFails() {
        let (store, client) = makeStore()
        SendBridge.dryRunOutcome = .failure(.scriptFailed("Messages isn't running"))

        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))
        settle()

        let rec = store.data.sendLog.first { $0.clientID == client.id }
        guard case .failed = rec?.status else {
            return XCTFail("expected a failed record, got \(String(describing: rec?.status))")
        }
        XCTAssertEqual(published.map(\.1), [1],
                       "a failed TEXT must not stop the week reaching her phone")
    }

    func testFailedSendNotifiesTheCoach() {
        let (store, _) = makeStore()
        SendBridge.dryRunOutcome = .failure(.scriptFailed("Messages isn't running"))

        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))

        XCTAssertTrue(notes.contains { $0.0.contains("did NOT reach Lauri") },
                      "a failed send must be loud; got \(notes.map(\.0))")
    }

    func testAttentionCountCoversQueuedAndFailed() {
        let (store, _) = makeStore()
        SendBridge.dryRunOutcome = .failure(.scriptFailed("nope"))
        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))
        XCTAssertEqual(store.attentionCount, 1)
    }

    // MARK: - doctrine: unapproved content never reaches her

    func testQueuedWeekIsNeverPublished() {
        let (store, _) = makeStore(review: true)

        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))
        settle()

        XCTAssertTrue(store.data.sendLog.contains { if case .queued = $0.status { return true }; return false })
        XCTAssertTrue(published.isEmpty,
                      "a week awaiting the coach's approval must never hit her phone")
    }

    func testQueuedSendNotifiesTheCoach() {
        let (store, _) = makeStore(review: true)
        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))
        XCTAssertTrue(notes.contains { $0.0.contains("waiting for you") },
                      "got \(notes.map(\.0))")
    }

    // MARK: - retry semantics

    func testConfirmedPublishIsNotRepeated() {
        let (store, _) = makeStore()
        let now = monday.addingTimeInterval(10 * 3600)

        store.runDeliveryPass(now: now)
        settle()
        store.runDeliveryPass(now: now.addingTimeInterval(3600))
        settle()

        XCTAssertEqual(published.count, 1, "a confirmed mirror must not be republished")
        XCTAssertNotNil(store.data.sendLog.first?.publishedAt)
    }

    func testUnconfirmedPublishIsRetriedNextPass() {
        let (store, _) = makeStore()
        var attempts = 0
        SyncService.publishCapture = { [weak self] id, week, _ in
            attempts += 1
            self?.published.append((id, week))
            return attempts > 1          // first attempt fails, second lands
        }
        let now = monday.addingTimeInterval(10 * 3600)

        store.runDeliveryPass(now: now)
        settle()
        XCTAssertNil(store.data.sendLog.first?.publishedAt, "unconfirmed must stay unconfirmed")

        store.runDeliveryPass(now: now.addingTimeInterval(3600))
        settle()
        XCTAssertEqual(attempts, 2, "an unconfirmed mirror retries on the next pass")
        XCTAssertNotNil(store.data.sendLog.first?.publishedAt)
    }

    func testSuccessfulRetryClearsAttention() {
        let (store, _) = makeStore()
        SendBridge.dryRunOutcome = .failure(.scriptFailed("nope"))
        store.runDeliveryPass(now: monday.addingTimeInterval(10 * 3600))
        settle()
        XCTAssertEqual(store.attentionCount, 1)

        SendBridge.dryRunOutcome = .success(())
        guard let failed = store.data.sendLog.first(where: {
            if case .failed = $0.status { return true }; return false
        }) else { return XCTFail("no failed record to retry") }
        store.retryFailed(failed.id)
        settle()

        XCTAssertEqual(store.attentionCount, 0, "a successful retry resolves the attention item")
    }

    func testNagIsAtMostOncePerDayWhileUnresolved() {
        let (store, _) = makeStore()
        SendBridge.dryRunOutcome = .failure(.scriptFailed("nope"))
        let t0 = monday.addingTimeInterval(10 * 3600)

        store.runDeliveryPass(now: t0)
        let afterFirst = notes.count
        XCTAssertEqual(afterFirst, 1, "first sighting notifies immediately")

        store.nagAttention(now: t0.addingTimeInterval(23 * 3600))
        XCTAssertEqual(notes.count, afterFirst, "still quiet inside 24h")

        store.nagAttention(now: t0.addingTimeInterval(25 * 3600))
        XCTAssertEqual(notes.count, afterFirst + 1, "re-nags once a day while unresolved")
    }

    // MARK: - the pairing gap that started all this

    func testPairedMidWeekBackfillsWithoutAnotherSend() {
        let (store, client) = makeStore()
        let now = monday.addingTimeInterval(10 * 3600)
        store.runDeliveryPass(now: now)
        settle()
        XCTAssertEqual(published.count, 1)

        // Simulate "she paired later and the server row is gone/never landed":
        // forget the confirmation, and the next pass must re-mirror with no
        // new text going out.
        let sendsBefore = store.data.sendLog.count
        store.republishCurrentWeek(clientID: client.id, now: now)
        settle()

        XCTAssertEqual(published.count, 2, "republish re-mirrors the current week")
        XCTAssertEqual(store.data.sendLog.count, sendsBefore,
                       "republishing must NOT send her another text")
    }

    // MARK: - notes must never be silent

    func testSubmittedNoteNotifiesEvenWithNoFlags() {
        let (store, client) = makeStore()
        let sub = Submission(clientID: client.id, performedAt: Date(),
                             lift: .squat, load: 185, unit: .lb, reps: 6, rpe: 7,
                             note: "left hip pinched on rep 4")
        store.ingest(sub)

        XCTAssertTrue(notes.contains { $0.0.contains("Note from Lauri") },
                      "a note on a clean set must still reach the coach; got \(notes.map(\.0))")
    }

    func testInboxSummaryCarriesTheNote() {
        let (store, client) = makeStore()
        let sub = Submission(clientID: client.id, performedAt: Date(),
                             lift: .squat, load: 185, unit: .lb, reps: 6, rpe: 7,
                             note: "left hip pinched on rep 4")
        let rec = store.ingest(sub)
        XCTAssertTrue(rec?.summary.contains("left hip pinched") == true,
                      "got \(rec?.summary ?? "nil")")
    }
}
