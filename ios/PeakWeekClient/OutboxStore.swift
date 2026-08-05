import Foundation
import Network
import PeakWeekCore

/// One queued result on its way to the coach. Survives app restarts; the
/// id is the end-to-end idempotency key, so retries can never double-log.
struct PendingSubmission: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var performedAt: Date
    var lift: String                  // squat / bench / deadlift
    var exerciseName: String?
    var load: Double
    var unit: String                  // what the lifter typed — never converted here
    var reps: Int
    var rpe: Double?
    var prescribedPct: Double?
    var prescribedRPE: Double?
    var weekNum: Int?
    var programStamp: Date?
    var note: String?
    var videoLocalPath: String?       // file in the app container awaiting upload
    var state: State = .queued

    enum State: String, Codable {
        case queued           // not yet accepted by the server
        case uploadingVideo   // row accepted; video still going up
        case delivered        // done (video too, if any)
    }
}

/// A queued free-text note to the coach.
struct PendingNote: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var body: String
    var createdAt: Date = Date()
    var delivered: Bool = false
}

/// Persistent offline queue. Flush on demand, on foreground, and when the
/// network comes back — the gym's dead corner must never eat a result.
@MainActor
final class OutboxStore: ObservableObject {
    @Published private(set) var items: [PendingSubmission] = []
    @Published private(set) var notes: [PendingNote] = []

    private let monitor = NWPathMonitor()
    private var flushOnReconnect = false

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("outbox.json")
    }
    private static var notesURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("outbox-notes.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            items = (try? dec.decode([PendingSubmission].self, from: data)) ?? []
        }
        if let data = try? Data(contentsOf: Self.notesURL) {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            notes = (try? dec.decode([PendingNote].self, from: data)) ?? []
        }
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                guard let self, self.flushOnReconnect, let token = Keychain.token() else { return }
                self.flushOnReconnect = false
                await self.flush(token: token)
            }
        }
        monitor.start(queue: .main)
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(
            at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(items).write(to: Self.fileURL, options: .atomic)
    }

    func enqueue(_ pending: PendingSubmission) {
        items.append(pending)
        save()
    }

    func enqueueNote(_ note: PendingNote) {
        notes.append(note)
        saveNotes()
    }

    private func saveNotes() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? enc.encode(notes).write(to: Self.notesURL, options: .atomic)
    }

    var undeliveredNotes: [PendingNote] { notes.filter { !$0.delivered } }

    var undelivered: [PendingSubmission] {
        items.filter { $0.state != .delivered }
    }

    /// Push everything undelivered. Item-by-item; a failure leaves the item
    /// queued and arms the reconnect trigger.
    func flush(token: String) async {
        for idx in notes.indices where !notes[idx].delivered {
            do {
                try await API.postNote(id: notes[idx].id, body: notes[idx].body, token: token)
                notes[idx].delivered = true
                saveNotes()
            } catch { flushOnReconnect = true }
        }
        if notes.count > 30 {
            notes.removeAll { $0.delivered && $0.createdAt < Date().addingTimeInterval(-7 * 86400) }
            saveNotes()
        }
        for idx in items.indices where items[idx].state != .delivered {
            var item = items[idx]
            do {
                if item.state == .queued {
                    let ticket = try await API.submit(item, token: token)
                    if let ticket, let localPath = item.videoLocalPath {
                        item.state = .uploadingVideo
                        items[idx] = item; save()
                        try await API.uploadVideo(
                            fileURL: URL(fileURLWithPath: localPath), ticket: ticket)
                        await API.videoDone(submissionID: item.id, token: token)
                        try? FileManager.default.removeItem(atPath: localPath)
                    }
                    item.state = .delivered
                    item.videoLocalPath = nil
                    items[idx] = item; save()
                } else if item.state == .uploadingVideo {
                    // Row exists server-side; re-request a ticket by resubmitting
                    // (idempotent id) and finish the video.
                    let ticket = try await API.submit(item, token: token)
                    if let ticket, let localPath = item.videoLocalPath {
                        try await API.uploadVideo(
                            fileURL: URL(fileURLWithPath: localPath), ticket: ticket)
                        await API.videoDone(submissionID: item.id, token: token)
                        try? FileManager.default.removeItem(atPath: localPath)
                    }
                    item.state = .delivered
                    item.videoLocalPath = nil
                    items[idx] = item; save()
                }
            } catch {
                flushOnReconnect = true
            }
        }
        // Keep the last 50 delivered for the history screen; drop the rest.
        if items.count > 80 {
            let delivered = items.filter { $0.state == .delivered }
            if delivered.count > 50 {
                let cut = delivered.count - 50
                var removed = 0
                items.removeAll {
                    if $0.state == .delivered, removed < cut { removed += 1; return true }
                    return false
                }
                save()
            }
        }
    }
}
