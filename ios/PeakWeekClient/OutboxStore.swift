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

    // Added after v1.1. OPTIONAL on purpose: the whole outbox decode is
    // `try? decode(...) ?? []`, so a non-optional addition would silently
    // discard every queued result on the first launch after an update.
    var attempts: Int?
    var lastError: String?
    var lastTriedAt: Date?
    /// The upload was abandoned but the set itself was delivered — the lifter
    /// should be told rather than left watching a spinner forever.
    var videoLost: Bool?

    enum State: String, Codable {
        case queued           // not yet accepted by the server
        case uploadingVideo   // row accepted; video still going up
        case delivered        // done (video too, if any)
    }

    /// Tried enough times, and long enough ago, that calling it "sending" is a
    /// lie. Drives the lifter-visible failure state.
    var looksStuck: Bool {
        guard state != .delivered, let n = attempts, n >= 3, let last = lastTriedAt else { return false }
        return Date().timeIntervalSince(last) > 600
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

    /// `flush` is async and every `await` inside it releases the main actor, so
    /// without this two callers interleave — and two flushes DO happen on every
    /// cold launch (scenePhase .active plus MainTabs.task). Interleaved writes
    /// could strand a submission in .uploadingVideo pointing at a file the
    /// other flush had already deleted, which is unrecoverable and invisible.
    private var isFlushing = false
    private var flushAgain = false

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

        // A background upload can finish while the app is suspended, or even
        // relaunch us to say so. Finish the handshake wherever we are.
        VideoUploader.shared.onFinished = { [weak self] id, error in
            Task { @MainActor [weak self] in
                await self?.videoUploadFinished(id: id, error: error)
            }
        }
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(
            at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(items).write(to: Self.fileURL, options: .atomic)
    }

    private func saveNotes() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? enc.encode(notes).write(to: Self.notesURL, options: .atomic)
    }

    func enqueue(_ pending: PendingSubmission) {
        items.append(pending)
        save()
    }

    func enqueueNote(_ note: PendingNote) {
        notes.append(note)
        saveNotes()
    }

    var undeliveredNotes: [PendingNote] { notes.filter { !$0.delivered } }

    var undelivered: [PendingSubmission] {
        items.filter { $0.state != .delivered }
    }

    /// Anything the lifter should be told about rather than left guessing.
    var stuck: [PendingSubmission] { items.filter(\.looksStuck) }

    /// Mutate one row by IDENTITY. Never hold an index across an `await` —
    /// the array can be pruned or appended to in between.
    private func mutate(_ id: UUID, _ change: (inout PendingSubmission) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    private func item(_ id: UUID) -> PendingSubmission? {
        items.first { $0.id == id }
    }

    /// Push everything undelivered. Re-entrant callers coalesce into one run.
    func flush(token: String) async {
        guard !isFlushing else { flushAgain = true; return }
        isFlushing = true
        defer { isFlushing = false }
        repeat {
            flushAgain = false
            await flushOnce(token: token)
        } while flushAgain
    }

    private func flushOnce(token: String) async {
        for id in undeliveredNotes.map(\.id) {
            guard let note = notes.first(where: { $0.id == id }), !note.delivered else { continue }
            do {
                try await API.postNote(id: id, body: note.body, token: token)
                if let i = notes.firstIndex(where: { $0.id == id }) {
                    notes[i].delivered = true
                    saveNotes()
                }
            } catch { flushOnReconnect = true }
        }
        if notes.count > 30 {
            notes.removeAll { $0.delivered && $0.createdAt < Date().addingTimeInterval(-7 * 86400) }
            saveNotes()
        }

        // Don't start a second transfer for a video the system is already
        // carrying — that's how you get two uploads racing to delete one file.
        let inFlight = await VideoUploader.shared.activeSubmissionIDs()

        for id in undelivered.map(\.id) {
            guard let current = item(id), current.state != .delivered else { continue }
            if inFlight.contains(id) { continue }
            mutate(id) {
                $0.attempts = ($0.attempts ?? 0) + 1
                $0.lastTriedAt = Date()
            }
            guard let pending = item(id) else { continue }
            do {
                // Idempotent by id, so re-submitting an accepted row is safe and
                // is also how we re-obtain an upload ticket after an interruption.
                let ticket = try await API.submit(pending, token: token)
                guard let fresh = item(id) else { continue }

                guard let ticket, let localPath = fresh.videoLocalPath else {
                    mutate(id) { $0.state = .delivered; $0.videoLocalPath = nil; $0.lastError = nil }
                    continue
                }
                // The file is gone (a previous crash, or the OS reclaimed it).
                // The SET is safely server-side, so finish it and say the video
                // was lost rather than retrying against nothing forever.
                guard FileManager.default.fileExists(atPath: localPath) else {
                    await API.videoDone(submissionID: id, token: token)
                    mutate(id) {
                        $0.state = .delivered
                        $0.videoLocalPath = nil
                        $0.videoLost = true
                        $0.lastError = "The video couldn't be found on this phone."
                    }
                    continue
                }
                mutate(id) { $0.state = .uploadingVideo; $0.lastError = nil }
                VideoUploader.shared.upload(fileURL: URL(fileURLWithPath: localPath),
                                            ticket: ticket, submissionID: id)
            } catch {
                flushOnReconnect = true
                mutate(id) { $0.lastError = (error as? APIError)?.message ?? error.localizedDescription }
            }
        }

        prune()
    }

    /// The background session finished carrying one video.
    private func videoUploadFinished(id: UUID, error: Error?) async {
        guard let pending = item(id) else { return }
        if let error {
            flushOnReconnect = true
            mutate(id) {
                $0.state = .uploadingVideo          // stays retryable
                $0.lastError = (error as? APIError)?.message ?? error.localizedDescription
            }
            return
        }
        guard let token = Keychain.token() else { return }
        await API.videoDone(submissionID: id, token: token)
        if let path = pending.videoLocalPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        mutate(id) { $0.state = .delivered; $0.videoLocalPath = nil; $0.lastError = nil }
    }

    /// Manual "try again" from the history screen.
    func retry(_ id: UUID, token: String) async {
        mutate(id) { $0.attempts = 0; $0.lastError = nil }
        await flush(token: token)
    }

    /// Keep the last 50 delivered for the history screen; drop the rest.
    private func prune() {
        guard items.count > 80 else { return }
        let delivered = items.filter { $0.state == .delivered }
        guard delivered.count > 50 else { return }
        let cut = delivered.count - 50
        var removed = 0
        items.removeAll {
            if $0.state == .delivered, removed < cut { removed += 1; return true }
            return false
        }
        save()
    }
}
