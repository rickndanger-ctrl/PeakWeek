import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppStore: ObservableObject {

    @Published var data = AppData() {
        didSet { save() }
    }

    private var loading = false
    private var deliveryTimer: Timer?

    static let dataURL: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeakWeek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    init() {
        load()
        // Automated delivery: catch up shortly after launch, then check hourly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.runDeliveryPass()
        }
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.runDeliveryPass()
        }
    }

    func load() {
        loading = true
        defer { loading = false }
        guard let raw = try? Data(contentsOf: Self.dataURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let decoded = try? dec.decode(AppData.self, from: raw) {
            data = decoded
        }
    }

    func save() {
        if loading { return }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? enc.encode(data) {
            try? raw.write(to: Self.dataURL, options: .atomic)
        }
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
        data.clients.removeAll { $0.id == id }
    }

    // MARK: automated delivery

    /// One pass over all clients: queue or send anything due. Idempotent —
    /// covered weeks are recorded in the send log and never re-sent.
    func runDeliveryPass(now: Date = Date()) {
        var newRecords: [SendRecord] = []
        for client in data.clients {
            let records = data.sendLog.filter { $0.clientID == client.id }
            guard let due = DeliverySchedule.dueSend(now: now, startDate: client.startDate,
                                                     program: client.program,
                                                     prefs: client.delivery,
                                                     records: records) else { continue }
            for old in due.supersededWeeks {
                newRecords.append(SendRecord(clientID: client.id, clientName: client.name,
                                             weekNum: old, date: now,
                                             method: client.delivery.method,
                                             status: .skipped("superseded by week \(due.weekNum)")))
            }
            if client.delivery.requireReview {
                newRecords.append(SendRecord(clientID: client.id, clientName: client.name,
                                             weekNum: due.weekNum, date: now,
                                             method: client.delivery.method,
                                             status: .queued))
            } else {
                newRecords.append(performSend(client: client, weekNum: due.weekNum, now: now))
            }
        }
        if !newRecords.isEmpty {
            data.sendLog.append(contentsOf: newRecords)
        }
    }

    /// Executes one send through the bridge and returns the outcome record.
    func performSend(client: Client, weekNum: Int, now: Date = Date()) -> SendRecord {
        func record(_ status: SendStatus) -> SendRecord {
            SendRecord(clientID: client.id, clientName: client.name, weekNum: weekNum,
                       date: now, method: client.delivery.method, status: status)
        }
        guard let program = client.program,
              let week = program.weeks.first(where: { $0.num == weekNum }) else {
            return record(.failed("program/week no longer exists"))
        }
        let text = Engine.weekToText(client: client, program: program, week: week)
        var attachment: URL?
        if client.delivery.format != .text {
            attachment = WeekExporter.writeTempPDF(client: client, program: program, week: week)
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
    func approveQueued(_ recordID: UUID) {
        guard let idx = data.sendLog.firstIndex(where: { $0.id == recordID }),
              case .queued = data.sendLog[idx].status,
              let client = data.clients.first(where: { $0.id == data.sendLog[idx].clientID })
        else { return }
        let outcome = performSend(client: client, weekNum: data.sendLog[idx].weekNum)
        data.sendLog[idx].status = outcome.status
        data.sendLog[idx].date = outcome.date
    }

    func dismissQueued(_ recordID: UUID) {
        guard let idx = data.sendLog.firstIndex(where: { $0.id == recordID }),
              case .queued = data.sendLog[idx].status else { return }
        data.sendLog[idx].status = .skipped("dismissed by coach")
    }

    var queuedSends: [SendRecord] {
        data.sendLog.filter { if case .queued = $0.status { return true }; return false }
    }

    // MARK: backup / restore

    func exportBackup() {
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
        data = decoded
        return true
    }
}
