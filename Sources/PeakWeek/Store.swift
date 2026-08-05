import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppStore: ObservableObject {

    @Published var data = AppData() {
        didSet { scheduleSave() }
    }

    /// True when data.json exists but could not be decoded. While set, saving is
    /// REFUSED — the app must never overwrite a file it couldn't read.
    /// Cleared ONLY by a successful restore — never by UI dismissal.
    @Published private(set) var loadFailed = false

    /// Drives the recovery alert. Separate from `loadFailed` so dismissing the
    /// alert (or a failed restore attempt) can never unfreeze writes.
    @Published var showLoadFailedAlert = false

    private var loading = false
    private var deliveryTimer: Timer?
    private var pendingSave: DispatchWorkItem?
    private var terminateObserver: NSObjectProtocol?

    /// One-shot consent for writing an EMPTY roster over a non-empty file.
    /// Only explicit user actions (deleting the last client, restoring an
    /// empty backup) set this. Anything else attempting such a write is
    /// treated as state corruption and refused.
    private var allowEmptyRosterWrite = false

    static let dataURL: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeakWeek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    static var backupURL: URL {
        dataURL.deletingLastPathComponent().appendingPathComponent("data.json.bak")
    }

    /// TEST-ONLY: an in-memory store that never reads or writes data.json and
    /// starts no timers. Production code must never call this — the real
    /// initializer below is the only path that touches disk.
    init(inMemory: Bool) {
        persistenceDisabled = true
    }

    /// One-way switch set only by the in-memory initializer.
    private var persistenceDisabled = false

    init() {
        load()
        // Automated delivery: catch up shortly after launch, then check hourly.
        // The inbound sync poll rides the same cadence.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.runDeliveryPass()
            self?.syncNow()
        }
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runDeliveryPass()
            self?.syncNow()
        }
        // Flush any debounced save before quitting.
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.saveNow()
        }
    }

    func load() {
        loading = true
        defer { loading = false }
        guard FileManager.default.fileExists(atPath: Self.dataURL.path) else { return } // fresh start
        guard let raw = try? Data(contentsOf: Self.dataURL) else {
            // File EXISTS but can't even be read (I/O/permissions) — that is a
            // failure, not a fresh start. Freeze writes.
            loadFailed = true
            showLoadFailedAlert = true
            return
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let decoded = try? dec.decode(AppData.self, from: raw) {
            data = decoded
        } else {
            // File exists but can't be decoded — freeze writes and let the UI offer recovery.
            loadFailed = true
            showLoadFailedAlert = true
        }
    }

    /// Debounced save: the didSet fires on every keystroke; disk sees at most
    /// one write per second. saveNow() flushes immediately (quit, backup).
    private func scheduleSave() {
        if loading || persistenceDisabled { return }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        if loading || loadFailed || persistenceDisabled { return }   // never clobber a file we couldn't read
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let raw = try? enc.encode(data) else { return }
        let fm = FileManager.default
        // Rotate a one-generation safety copy before every write — but ONLY if
        // the current on-disk file actually decodes. A corrupt data.json must
        // never overwrite a good .bak.
        var onDisk: AppData?
        if let existing = try? Data(contentsOf: Self.dataURL) {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            onDisk = try? dec.decode(AppData.self, from: existing)
            if onDisk != nil {
                try? fm.removeItem(at: Self.backupURL)
                try? fm.copyItem(at: Self.dataURL, to: Self.backupURL)
            }
        }
        // Last line of defense: never silently replace a roster with nothing.
        // An empty write is only honored when an explicit user action armed it.
        if data.clients.isEmpty, let onDisk, !onDisk.clients.isEmpty, !allowEmptyRosterWrite {
            NSLog("PeakWeek: REFUSED suspicious empty-roster write over %d client(s)",
                  onDisk.clients.count)
            return
        }
        allowEmptyRosterWrite = false
        try? raw.write(to: Self.dataURL, options: .atomic)
    }

    /// Restore from the automatic .bak (decode-failure recovery path).
    func restoreAutomaticBackup() -> Bool {
        guard let raw = try? Data(contentsOf: Self.backupURL) else { return false }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let decoded = try? dec.decode(AppData.self, from: raw) else { return false }
        loadFailed = false
        allowEmptyRosterWrite = decoded.clients.isEmpty   // restoring an empty backup is explicit
        data = decoded
        return true
    }

    // MARK: client helpers

    func clientIndex(_ id: UUID) -> Int? {
        data.clients.firstIndex { $0.id == id }
    }

    func binding(for id: UUID) -> Binding<Client>? {
        guard clientIndex(id) != nil else { return nil }
        return Binding(
            get: {
                guard let i = self.clientIndex(id) else { return Client(name: "") }
                return self.data.clients[i]
            },
            set: { newValue in
                guard let i = self.clientIndex(id) else { return }
                self.data.clients[i] = newValue
            }
        )
    }

    func addClient(_ c: Client) { data.clients.append(c) }

    func deleteClient(_ id: UUID) {
        if data.clients.count == 1, data.clients[0].id == id {
            allowEmptyRosterWrite = true      // deleting the LAST client is explicit
        }
        data.clients.removeAll { $0.id == id }
        // Retire any pending queue entries so the badge stays honest; keep
        // terminal history for the record.
        for i in data.sendLog.indices where data.sendLog[i].clientID == id {
            if case .queued = data.sendLog[i].status {
                data.sendLog[i].status = .skipped("client deleted")
            }
        }
    }

    // MARK: automated delivery

    /// One pass over all clients: queue or send anything due. Idempotent —
    /// covered weeks are recorded in the send log and never re-sent, and a
    /// week that is already queued is never queued twice.
    func runDeliveryPass(now: Date = Date()) {
        cleanupShareTempFiles()
        var log = data.sendLog
        var changed = false
        for client in data.clients {
            let records = log.filter { $0.clientID == client.id }
            guard let due = DeliverySchedule.dueSend(now: now, startDate: client.startDate,
                                                     program: client.program,
                                                     prefs: client.delivery,
                                                     records: records) else { continue }
            let stamp = client.program?.createdAt
            // Retire superseded weeks: convert their queued records in place and
            // add a terminal skipped record so they never come due again.
            for old in due.supersededWeeks {
                for i in log.indices where log[i].clientID == client.id
                    && log[i].weekNum == old
                    && (log[i].programStamp == nil || log[i].programStamp == stamp) {
                    if case .queued = log[i].status {
                        log[i].status = .skipped("superseded by week \(due.weekNum)")
                        log[i].date = now
                        changed = true
                    }
                }
                if !log.contains(where: { $0.clientID == client.id && $0.weekNum == old
                    && ($0.programStamp == nil || $0.programStamp == stamp)
                    && $0.status.isTerminal }) {
                    log.append(SendRecord(clientID: client.id, clientName: client.name,
                                          weekNum: old, date: now,
                                          method: client.delivery.method,
                                          status: .skipped("superseded by week \(due.weekNum)"),
                                          programStamp: stamp))
                    changed = true
                }
            }
            // One-time forced review after a regeneration protects against an
            // unconfirmed automatic (re)send while the coach is still editing.
            let needsReview = client.delivery.requireReview || client.delivery.forceReviewOnce == true
            if needsReview {
                if !due.alreadyQueued {
                    log.append(SendRecord(clientID: client.id, clientName: client.name,
                                          weekNum: due.weekNum, date: now,
                                          method: client.delivery.method,
                                          status: .queued, programStamp: stamp))
                    changed = true
                }
                if client.delivery.forceReviewOnce == true,
                   let ci = data.clients.firstIndex(where: { $0.id == client.id }) {
                    data.clients[ci].delivery.forceReviewOnce = nil
                }
            } else {
                log.append(performSend(client: client, weekNum: due.weekNum, now: now))
                // A week sent by ANY path retires its queue entries — a stale
                // approvable record is a double-send waiting to happen.
                Self.retireQueued(in: &log, clientID: client.id, weekNum: due.weekNum,
                                  stamp: stamp, reason: "already sent")
                changed = true
            }
        }
        if changed {
            data.sendLog = log
        }
    }

    /// Retire queued review entries for a week that has been delivered by
    /// another path (auto-send after review was disabled, manual Send Now…).
    static func retireQueued(in log: inout [SendRecord], clientID: UUID, weekNum: Int,
                             stamp: Date?, reason: String) {
        for i in log.indices where log[i].clientID == clientID
            && log[i].weekNum == weekNum
            && (log[i].programStamp == nil || log[i].programStamp == stamp) {
            if case .queued = log[i].status {
                log[i].status = .skipped(reason)
                log[i].date = Date()
            }
        }
    }

    /// Temp PDFs handed to the share sheet / senders: sweep anything older
    /// than a day (files now live one directory deep, per client).
    private func cleanupShareTempFiles() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeakWeekShare", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]) else { return }
        let cutoff = Date().addingTimeInterval(-86400)
        func sweep(_ url: URL) {
            let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            if vals?.isDirectory == true {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
                children.forEach(sweep)
                if ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).isEmpty {
                    try? FileManager.default.removeItem(at: url)
                }
            } else if let mod = vals?.contentModificationDate, mod < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
        contents.forEach(sweep)
    }

    /// Executes one send through the bridge and returns the outcome record.
    func performSend(client: Client, weekNum: Int, now: Date = Date()) -> SendRecord {
        func record(_ status: SendStatus) -> SendRecord {
            SendRecord(clientID: client.id, clientName: client.name, weekNum: weekNum,
                       date: now, method: client.delivery.method, status: status,
                       programStamp: client.program?.createdAt)
        }
        guard let program = client.program,
              let week = program.weeks.first(where: { $0.num == weekNum }) else {
            return record(.failed("program/week no longer exists"))
        }
        let text = Engine.weekToText(client: client, program: program, week: week,
                                     library: data.exerciseLibrary)
        var attachment: URL?
        if client.delivery.format != .text {
            attachment = WeekExporter.writeTempPDF(client: client, program: program, week: week,
                                                   library: data.exerciseLibrary)
            if attachment == nil { return record(.failed("PDF generation failed")) }
        }
        let body = client.delivery.format == .pdf ? nil : text
        let result = SendBridge.send(via: client.delivery.method,
                                     to: client.delivery.recipient,
                                     subject: "\(client.name) — Week \(weekNum) training plan",
                                     text: body, attachment: attachment)
        switch result {
        case .success:
            // The client app mirrors exactly what was SENT — one week, the
            // latest only. Fire-and-forget; iMessage stays the channel of record.
            SyncService.publishWeek(client: client, program: program, week: week,
                                    library: data.exerciseLibrary)
            return record(.sent)
        case .failure(let err): return record(.failed(err.localizedDescription))
        }
    }

    // MARK: - inbound pipeline (client-app submissions)

    /// Ingest one client submission: convert units, run the anomaly check,
    /// AUTO-LOG into the client's history (flagged or not — the coach
    /// reviews, the data is never held hostage), record the audit row, and
    /// notify on flags. Idempotent by submission ID; refuses to run while
    /// the write freeze is active (ingested state would evaporate unsaved).
    @discardableResult
    func ingest(_ sub: Submission) -> IngestRecord? {
        guard !loadFailed else { return nil }
        guard let ci = data.clients.firstIndex(where: { $0.id == sub.clientID })
        else {
            NSLog("PeakWeek ingest: no client with id %@ — submission %@ skipped",
                  sub.clientID.uuidString, sub.id.uuidString)
            return nil
        }
        // Idempotency: this submission already landed (retry / re-delivery).
        guard !data.clients[ci].logs.contains(where: { $0.submissionID == sub.id })
        else { return nil }

        var entry = Ingest.entry(from: sub, clientUnit: data.clients[ci].unit)
        let flags = AnomalyCheck.check(entry: entry, client: data.clients[ci])
        entry.flags = flags.isEmpty ? nil : flags

        let record = IngestRecord(
            submissionID: sub.id,
            clientID: sub.clientID,
            clientName: data.clients[ci].name,
            date: Date(),
            performedAt: sub.performedAt,
            summary: Ingest.summary(for: entry, unit: data.clients[ci].unit),
            flags: flags,
            videoFilename: sub.videoFilename)

        data.clients[ci].logs.append(entry)
        data.inboxLog.append(record)

        if !flags.isEmpty {
            Notifier.flaggedSubmission(clientName: record.clientName,
                                       summary: record.summary, flags: flags)
        }
        return record
    }

    /// Ingest a free-text note from the client app: inbox row + notification,
    /// no log entry (notes are messages, not data). Idempotent by note ID.
    @discardableResult
    func ingestNote(_ note: ClientNote) -> IngestRecord? {
        guard !loadFailed else { return nil }
        guard let ci = data.clients.firstIndex(where: { $0.id == note.clientID })
        else { return nil }
        guard !data.inboxLog.contains(where: { $0.submissionID == note.id })
        else { return nil }
        let record = IngestRecord(
            submissionID: note.id,
            clientID: note.clientID,
            clientName: data.clients[ci].name,
            date: Date(),
            performedAt: note.createdAt,
            summary: note.body,
            state: .new,
            kind: .note)
        data.inboxLog.append(record)
        // Notes always notify — they're deliberate communication.
        Notifier.noteReceived(clientName: record.clientName, body: note.body)
        return record
    }

    /// Coach looked at a flagged (or any) submission — the data stands.
    func markIngestReviewed(_ recordID: UUID) {
        guard let idx = data.inboxLog.firstIndex(where: { $0.id == recordID }),
              data.inboxLog[idx].state == .new else { return }
        data.inboxLog[idx].state = .reviewed
    }

    /// Coach rejected a submission: the log entry it created is removed
    /// (found by submission ID — defensive re-lookup, never a stored index)
    /// and the audit row is kept as dismissed.
    func rejectIngest(_ recordID: UUID) {
        guard let idx = data.inboxLog.firstIndex(where: { $0.id == recordID }),
              data.inboxLog[idx].state != .dismissed else { return }
        let subID = data.inboxLog[idx].submissionID
        if let ci = data.clients.firstIndex(where: { $0.id == data.inboxLog[idx].clientID }) {
            data.clients[ci].logs.removeAll { $0.submissionID == subID }
        }
        data.inboxLog[idx].state = .dismissed
    }

    /// New (unreviewed) inbox rows — drives the toolbar badge.
    var newInboxCount: Int {
        data.inboxLog.filter { $0.state == .new }.count
    }

    /// Kick one inbound sync pass (poll → ingest → videos → ack) plus the
    /// local video retention sweep. Fire-and-forget; everything idempotent.
    func syncNow() {
        guard SyncService.isConfigured else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            _ = await SyncService.pollInbox(store: self)
            SyncService.cleanupVideoStorage()
        }
    }

    /// Immediate manual send from a week's Send menu.
    func sendNow(clientID: UUID, weekNum: Int) {
        guard let client = data.clients.first(where: { $0.id == clientID }) else { return }
        var log = data.sendLog
        log.append(performSend(client: client, weekNum: weekNum))
        Self.retireQueued(in: &log, clientID: clientID, weekNum: weekNum,
                          stamp: client.program?.createdAt, reason: "already sent manually")
        data.sendLog = log
    }

    /// Coach approved a queued send from the review sheet.
    /// A record queued under a program that has since been regenerated is NOT
    /// sent (its content no longer exists) — it's retired instead.
    func approveQueued(_ recordID: UUID) {
        guard let idx = data.sendLog.firstIndex(where: { $0.id == recordID }),
              case .queued = data.sendLog[idx].status,
              let client = data.clients.first(where: { $0.id == data.sendLog[idx].clientID })
        else { return }
        let currentStamp = client.program?.createdAt
        guard data.sendLog[idx].programStamp == nil || data.sendLog[idx].programStamp == currentStamp else {
            data.sendLog[idx].status = .skipped("program changed since this was queued")
            data.sendLog[idx].date = Date()
            return
        }
        // Defense in depth: if this week already went out by another path,
        // approving must NOT send it again.
        let weekNum = data.sendLog[idx].weekNum
        if data.sendLog.contains(where: { $0.clientID == client.id && $0.weekNum == weekNum
            && ($0.programStamp == nil || $0.programStamp == currentStamp)
            && $0.weekRemoved != true
            && { if case .sent = $0.status { return true }; return false }($0) }) {
            data.sendLog[idx].status = .skipped("already sent")
            data.sendLog[idx].date = Date()
            return
        }
        let outcome = performSend(client: client, weekNum: weekNum)
        data.sendLog[idx].status = outcome.status
        data.sendLog[idx].date = outcome.date
        data.sendLog[idx].programStamp = outcome.programStamp
    }

    func dismissQueued(_ recordID: UUID) {
        guard let idx = data.sendLog.firstIndex(where: { $0.id == recordID }),
              case .queued = data.sendLog[idx].status else { return }
        data.sendLog[idx].status = .skipped("dismissed by coach")
    }

    /// Manual retry of a failed automated send (failures never auto-retry —
    /// re-sending a text message must always be a human decision).
    func retryFailed(_ recordID: UUID) {
        guard let idx = data.sendLog.firstIndex(where: { $0.id == recordID }),
              case .failed = data.sendLog[idx].status,
              let client = data.clients.first(where: { $0.id == data.sendLog[idx].clientID })
        else { return }
        let currentStamp = client.program?.createdAt
        guard data.sendLog[idx].programStamp == nil || data.sendLog[idx].programStamp == currentStamp else {
            data.sendLog[idx].status = .skipped("program changed since this failed")
            data.sendLog[idx].date = Date()
            return
        }
        let outcome = performSend(client: client, weekNum: data.sendLog[idx].weekNum)
        data.sendLog[idx].status = outcome.status
        data.sendLog[idx].date = outcome.date
        data.sendLog[idx].programStamp = outcome.programStamp
    }

    /// Structural program edit (deload inserted/removed at week `fromWeek`):
    /// shift this program's send-log records so history stays aligned with the
    /// renumbered weeks. Queued records for a REMOVED week are retired.
    func adjustSendRecords(clientID: UUID, programStamp: Date?,
                           fromWeek: Int, by delta: Int, removedWeek: Int? = nil) {
        for i in data.sendLog.indices where data.sendLog[i].clientID == clientID
            && (data.sendLog[i].programStamp == nil || data.sendLog[i].programStamp == programStamp) {
            if let removed = removedWeek, data.sendLog[i].weekNum == removed {
                if case .queued = data.sendLog[i].status {
                    data.sendLog[i].status = .skipped("week removed from program")
                }
                // History stays, but a removed week's records must not cover
                // the week that inherits its number.
                data.sendLog[i].weekRemoved = true
                continue
            }
            if data.sendLog[i].weekNum >= fromWeek {
                data.sendLog[i].weekNum += delta
            }
        }
    }

    /// Called when a client's program is regenerated: anything still awaiting
    /// review for the OLD program is retired so it can't be approved into a
    /// stale or duplicate send.
    func retireStaleQueued(clientID: UUID, currentStamp: Date?) {
        for i in data.sendLog.indices where data.sendLog[i].clientID == clientID {
            if case .queued = data.sendLog[i].status,
               data.sendLog[i].programStamp != currentStamp {
                data.sendLog[i].status = .skipped("program regenerated")
                data.sendLog[i].date = Date()
            }
        }
    }

    var queuedSends: [SendRecord] {
        data.sendLog.filter { if case .queued = $0.status { return true }; return false }
    }

    // MARK: backup / restore

    func exportBackup() {
        guard !loadFailed else {
            let alert = NSAlert()
            alert.messageText = "Can't back up right now"
            alert.informativeText = "The data file couldn't be read, so a backup would be empty. Restore first."
            alert.runModal()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        panel.nameFieldStringValue = "peakweek-backup-\(stamp).json"
        panel.title = "Save Peak Week Backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? enc.encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    func importBackup() -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.title = "Restore Peak Week Backup"
        guard panel.runModal() == .OK, let url = panel.url,
              let raw = try? Data(contentsOf: url) else { return false }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let decoded = try? dec.decode(AppData.self, from: raw) else { return false }
        loadFailed = false          // a good backup un-freezes writes
        allowEmptyRosterWrite = decoded.clients.isEmpty   // restoring an empty backup is explicit
        data = decoded
        return true
    }
}
