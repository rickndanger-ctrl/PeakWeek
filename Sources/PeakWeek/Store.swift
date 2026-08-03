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

    init() {
        load()
        // Automated delivery: catch up shortly after launch, then check hourly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.runDeliveryPass()
        }
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runDeliveryPass()
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
        if loading { return }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        if loading || loadFailed { return }   // never clobber a file we couldn't read
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
            if client.delivery.requireReview {
                if !due.alreadyQueued {
                    log.append(SendRecord(clientID: client.id, clientName: client.name,
                                          weekNum: due.weekNum, date: now,
                                          method: client.delivery.method,
                                          status: .queued, programStamp: stamp))
                    changed = true
                }
            } else {
                log.append(performSend(client: client, weekNum: due.weekNum, now: now))
                changed = true
            }
        }
        if changed {
            data.sendLog = log
        }
    }

    /// Temp PDFs handed to the share sheet / senders: sweep anything older than a day.
    private func cleanupShareTempFiles() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeakWeekShare", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-86400)
        for f in files {
            let mod = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let mod, mod < cutoff {
                try? FileManager.default.removeItem(at: f)
            }
        }
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
        case .success: return record(.sent)
        case .failure(let err): return record(.failed(err.localizedDescription))
        }
    }

    /// Immediate manual send from a week's Send menu.
    func sendNow(clientID: UUID, weekNum: Int) {
        guard let client = data.clients.first(where: { $0.id == clientID }) else { return }
        data.sendLog.append(performSend(client: client, weekNum: weekNum))
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
        let outcome = performSend(client: client, weekNum: data.sendLog[idx].weekNum)
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
