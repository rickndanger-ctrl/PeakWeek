import XCTest
@testable import PeakWeek

/// Regression tests for the re-verification findings: stale queued records
/// across program regeneration must never produce duplicate or wrong sends.
final class RegenerationTests: XCTestCase {

    let lib = ExerciseLibrary.seeded()

    func testStaleQueuedRecordDetectableByStamp() {
        var c = Client(name: "T", unit: .lb, maxes: Maxes(squat: 405, bench: 275, deadlift: 495))
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let oldStamp = c.program!.createdAt
        let queued = SendRecord(clientID: c.id, clientName: c.name, weekNum: 3,
                                date: Date(), method: .messages, status: .queued,
                                programStamp: oldStamp)
        // Regenerate.
        c.program = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        XCTAssertNotEqual(queued.programStamp, c.program!.createdAt,
                          "stale record is distinguishable — the guard in approveQueued/retryFailed and retireStaleQueued key off this")
    }

    func testSendRecordDecodesWithoutStamp() throws {
        let json = """
        {"id":"6F1E9F0A-2222-4444-8888-ABCDEF012345",
         "clientID":"6F1E9F0A-2222-4444-8888-ABCDEF012346",
         "clientName":"Old","weekNum":2,"date":"2026-08-01T12:00:00Z",
         "method":"messages","status":{"sent":{}}}
        """
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let r = try dec.decode(SendRecord.self, from: Data(json.utf8))
        XCTAssertNil(r.programStamp)
        XCTAssertEqual(r.weekNum, 2)
    }
}
