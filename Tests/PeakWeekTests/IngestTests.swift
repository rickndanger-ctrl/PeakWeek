import XCTest
@testable import PeakWeek

/// The inbound pipeline: anomaly rules, unit conversion, idempotency,
/// provenance, and the audit trail. Doctrine: auto-log everything, flag
/// what looks off, never hold data hostage.
final class IngestTests: XCTestCase {

    private func date(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.date(from: s)!
    }

    private func makeClient() -> Client {
        var c = Client(name: "Pipeline Test",
                       maxes: Maxes(squat: 500, bench: 300, deadlift: 550))
        c.unit = .lb
        return c
    }

    // MARK: - anomaly rules (pure)

    func testCleanEntryHasNoFlags() {
        let c = makeClient()
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                             load: 400, reps: 5, rpe: 8, prescribedRPE: 8)
        XCTAssertTrue(AnomalyCheck.check(entry: e, client: c).isEmpty)
    }

    func testLoadOverMaxFlags() {
        let c = makeClient()
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .bench,
                             load: 330, reps: 1, rpe: 9)   // max 300, +10%
        let flags = AnomalyCheck.check(entry: e, client: c)
        XCTAssertTrue(flags.contains { $0.contains("above the stored max") }, "\(flags)")
    }

    func testE1RMSpikeVsRecentTrendFlags() {
        var c = makeClient()
        // Two honest recent points: e1RM ≈ 500 (405×4@8 → 483, 415×4@8 → 496).
        c.logs = [
            LiftLogEntry(date: date("2026-07-10"), lift: .squat, load: 405, reps: 4, rpe: 8),
            LiftLogEntry(date: date("2026-07-24"), lift: .squat, load: 415, reps: 4, rpe: 8),
        ]
        // Suddenly 475×4@8 → e1RM 567 ≈ +14% over best recent — flag.
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                             load: 475, reps: 4, rpe: 8)
        let flags = AnomalyCheck.check(entry: e, client: c)
        XCTAssertTrue(flags.contains { $0.contains("big jump") }, "\(flags)")

        // A normal +1.5% progression does NOT flag.
        let ok = LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                              load: 420, reps: 4, rpe: 8)
        XCTAssertFalse(AnomalyCheck.check(entry: ok, client: c)
            .contains { $0.contains("big jump") })
    }

    func testKgLbMixupFlags() {
        let c = makeClient()   // lb client, squat max 500
        // Prescribed 67% of 500 = 335 lb expected. Lifter types 152 (the KG
        // number for ~335 lb): 152 × 2.2046 = 335.1 → mix-up flag.
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                             load: 152, reps: 6, rpe: 7, prescribedPct: 67)
        let flags = AnomalyCheck.check(entry: e, client: c)
        XCTAssertTrue(flags.contains { $0.contains("kg/lb") }, "\(flags)")

        // The CORRECT load near expected does not trip it.
        let ok = LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                              load: 335, reps: 6, rpe: 7, prescribedPct: 67)
        XCTAssertFalse(AnomalyCheck.check(entry: ok, client: c)
            .contains { $0.contains("kg/lb") })
    }

    func testDuplicateSameDayFlags() {
        var c = makeClient()
        c.logs = [LiftLogEntry(date: date("2026-08-04"), lift: .deadlift,
                               load: 455, reps: 3, rpe: 8,
                               submissionID: UUID())]
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .deadlift,
                             load: 455, reps: 3, rpe: 8,
                             submissionID: UUID())
        let flags = AnomalyCheck.check(entry: e, client: c)
        XCTAssertTrue(flags.contains { $0.contains("duplicate") }, "\(flags)")
    }

    func testMissingRPESoftFlag() {
        let c = makeClient()
        let e = LiftLogEntry(date: date("2026-08-04"), lift: .bench,
                             load: 225, reps: 5, prescribedRPE: 8)
        XCTAssertTrue(AnomalyCheck.check(entry: e, client: c)
            .contains { $0.contains("no RPE") })
        // Singles without RPE don't nag.
        let single = LiftLogEntry(date: date("2026-08-04"), lift: .bench,
                                  load: 275, reps: 1, prescribedRPE: 8)
        XCTAssertFalse(AnomalyCheck.check(entry: single, client: c)
            .contains { $0.contains("no RPE") })
    }

    // MARK: - ingest through the store

    private func makeStore() -> (AppStore, UUID) {
        let store = AppStore(inMemory: true)   // never touches the real data.json
        var c = makeClient()
        c.id = UUID()
        store.data.clients = [c]
        store.data.inboxLog = []
        return (store, c.id)
    }

    func testIngestConvertsUnitsAndStampsProvenance() {
        let (store, cid) = makeStore()
        Notifier.capture = { _, _ in }
        defer { Notifier.capture = nil }
        // Client is lb; submission arrives in kg.
        let sub = Submission(clientID: cid, performedAt: date("2026-08-04"),
                             lift: .squat, load: 180, unit: .kg, reps: 5, rpe: 8)
        let rec = store.ingest(sub)
        XCTAssertNotNil(rec)
        let entry = store.data.clients[0].logs.last!
        XCTAssertEqual(entry.load, 180 * Maxes.lbPerKg, accuracy: 1e-9,
                       "exact conversion into the client's unit")
        XCTAssertEqual(entry.source, .client)
        XCTAssertEqual(entry.submissionID, sub.id)
        XCTAssertEqual(store.data.inboxLog.count, 1)
        XCTAssertEqual(store.data.inboxLog[0].submissionID, sub.id)
    }

    func testIngestIsIdempotent() {
        let (store, cid) = makeStore()
        Notifier.capture = { _, _ in }
        defer { Notifier.capture = nil }
        let sub = Submission(clientID: cid, performedAt: date("2026-08-04"),
                             lift: .bench, load: 225, unit: .lb, reps: 5, rpe: 8)
        XCTAssertNotNil(store.ingest(sub))
        XCTAssertNil(store.ingest(sub), "same submission ID must not double-log")
        XCTAssertEqual(store.data.clients[0].logs.count, 1)
        XCTAssertEqual(store.data.inboxLog.count, 1)
    }

    func testFlaggedIngestNotifiesAndCleanDoesNot() {
        let (store, cid) = makeStore()
        var notified: [String] = []
        Notifier.capture = { title, _ in notified.append(title) }
        defer { Notifier.capture = nil }

        let clean = Submission(clientID: cid, performedAt: date("2026-08-04"),
                               lift: .squat, load: 400, unit: .lb, reps: 5, rpe: 8)
        _ = store.ingest(clean)
        XCTAssertTrue(notified.isEmpty, "clean data ingests silently")

        let hot = Submission(clientID: cid, performedAt: date("2026-08-05"),
                             lift: .squat, load: 560, unit: .lb, reps: 1, rpe: 9)
        let rec = store.ingest(hot)!
        XCTAssertFalse(rec.flags.isEmpty)
        XCTAssertEqual(notified.count, 1, "flagged data notifies the coach")
        // The flagged entry STILL landed in the log — auto-log doctrine.
        XCTAssertEqual(store.data.clients[0].logs.count, 2)
    }

    func testRejectIngestRemovesTheLogEntry() {
        let (store, cid) = makeStore()
        Notifier.capture = { _, _ in }
        defer { Notifier.capture = nil }
        let sub = Submission(clientID: cid, performedAt: date("2026-08-04"),
                             lift: .deadlift, load: 900, unit: .lb, reps: 1)
        let rec = store.ingest(sub)!
        XCTAssertEqual(store.data.clients[0].logs.count, 1)

        store.rejectIngest(rec.id)
        XCTAssertTrue(store.data.clients[0].logs.isEmpty,
                      "rejecting pulls the entry back out of the log")
        XCTAssertEqual(store.data.inboxLog[0].state, .dismissed,
                       "the audit row stays, marked rejected")
    }

    func testUnknownClientIsSkippedSafely() {
        let (store, _) = makeStore()
        let sub = Submission(clientID: UUID(), performedAt: Date(),
                             lift: .squat, load: 300, unit: .lb, reps: 5)
        XCTAssertNil(store.ingest(sub))
        XCTAssertTrue(store.data.inboxLog.isEmpty)
    }

    // MARK: - persistence

    func testProvenanceFieldsRoundTripAndOldDataDecodes() throws {
        var c = makeClient()
        c.logs = [LiftLogEntry(date: date("2026-08-04"), lift: .squat,
                               load: 400, reps: 5, rpe: 8,
                               source: .client, submissionID: UUID(),
                               flags: ["load above the stored max"])]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let round = try dec.decode(Client.self, from: enc.encode(c))
        XCTAssertEqual(round.logs[0].source, .client)
        XCTAssertNotNil(round.logs[0].submissionID)
        XCTAssertEqual(round.logs[0].flags?.count, 1)

        // Entries saved before the pipeline decode as coach-entered.
        let legacy = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345","date":"2026-08-01T00:00:00Z",
        "lift":"squat","load":400,"reps":5,"rpe":8,"cleanSingle":false,"note":""}
        """
        let e = try dec.decode(LiftLogEntry.self, from: Data(legacy.utf8))
        XCTAssertNil(e.source, "nil source = coach, pre-pipeline")
        XCTAssertNil(e.flags)
    }

    func testInboxLogPersistsInAppData() throws {
        var data = AppData()
        data.inboxLog = [IngestRecord(submissionID: UUID(), clientID: UUID(),
                                      clientName: "Test", date: Date(),
                                      performedAt: Date(),
                                      summary: "Squat 400×5 @8",
                                      flags: ["no RPE reported"])]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let round = try dec.decode(AppData.self, from: enc.encode(data))
        XCTAssertEqual(round.inboxLog.count, 1)
        XCTAssertEqual(round.inboxLog[0].state, .new)

        // v1 files without inboxLog still decode.
        let v1 = """
        {"clients":[],"sendLog":[]}
        """
        let old = try dec.decode(AppData.self, from: Data(v1.utf8))
        XCTAssertTrue(old.inboxLog.isEmpty)
    }
}
