import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppStore: ObservableObject {

    @Published var data = AppData() {
        didSet { save() }
    }

    private var loading = false

    static let dataURL: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeakWeek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }()

    init() { load() }

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
