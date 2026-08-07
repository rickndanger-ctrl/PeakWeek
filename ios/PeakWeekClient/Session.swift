import Foundation
import SwiftUI
import Security
import PeakWeekCore

/// Device identity + cached state. The device token lives in the iOS
/// Keychain; the paired client identity and the latest published week are
/// cached to disk so the gym's dead spots don't blank the screen.
@MainActor
final class Session: ObservableObject {
    @Published var client: API.PairedClient?
    @Published var week: PublishedWeek?
    @Published var weekPublishedAt: Date?
    @Published var lastError: String?
    @Published private(set) var paired: Bool

    let outbox = OutboxStore()

    var isPaired: Bool { paired }

    init() {
        paired = Keychain.token() != nil
        client = Self.loadJSON("client.json")
        week = Self.loadJSON("week.json")
        #if DEBUG
        // Headless E2E hooks (simulator only, debug builds only): pair and
        // fire a canned submission from launch environment variables.
        if !paired, let code = ProcessInfo.processInfo.environment["PW_PAIR_CODE"] {
            Task { @MainActor in
                await self.pair(code: code)
                if ProcessInfo.processInfo.environment["PW_TEST_SUBMIT"] == "1" {
                    // PW_TEST_VIDEO exercises the background-upload handoff,
                    // which is the part no unit test can reach.
                    var videoPath: String?
                    if ProcessInfo.processInfo.environment["PW_TEST_VIDEO"] == "1" {
                        let dest = FileManager.default
                            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("pending-e2e-\(UUID().uuidString).mp4")
                        try? FileManager.default.createDirectory(
                            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try? Data(repeating: 0x42, count: 256 * 1024).write(to: dest)
                        videoPath = dest.path
                    }
                    var p = PendingSubmission(
                        performedAt: Date(), lift: "squat", load: 340,
                        unit: "lb", reps: 6, rpe: 7,
                        prescribedPct: 67, prescribedRPE: 7,
                        weekNum: self.week?.weekNum,
                        programStamp: self.week?.programStamp,
                        note: "sim E2E test")
                    p.videoLocalPath = videoPath
                    self.submit(p)
                }
            }
        }
        #endif
    }

    func pair(code: String) async {
        do {
            let device = await UIDevice.current.name
            let result = try await API.pair(code: code.trimmingCharacters(in: .whitespaces).uppercased(),
                                            deviceName: device)
            Keychain.setToken(result.token)
            WeekWatch.requestNotificationPermission()
            client = result.client
            Self.saveJSON(result.client, "client.json")
            paired = true
            lastError = nil
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() async {
        guard let token = Keychain.token() else { return }
        await outbox.flush(token: token)
        do {
            if let envelope = try await API.fetchWeek(token: token) {
                week = envelope.payload
                weekPublishedAt = envelope.publishedAt
                if let w = envelope.payload { Self.saveJSON(w, "week.json") }
                WeekWatch.markSeen(publishedAt: envelope.publishedAt)
            }
            lastError = nil
        } catch {
            // Offline is normal in a gym basement — cached week stands.
            if week == nil { lastError = error.localizedDescription }
        }
    }

    func submit(_ pending: PendingSubmission) {
        outbox.enqueue(pending)
        Task {
            if let token = Keychain.token() {
                await outbox.flush(token: token)
            }
        }
    }

    func submitNote(_ body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        outbox.enqueueNote(PendingNote(body: trimmed))
        Task {
            if let token = Keychain.token() {
                await outbox.flush(token: token)
            }
        }
    }

    // MARK: day check-offs (local only — a rhythm aid, not coach data)

    @Published var doneDays: Set<String> = Session.loadJSON("done-days.json") ?? []

    func dayKey(_ week: PublishedWeek, dayIndex: Int) -> String {
        "\(Int(week.programStamp.timeIntervalSince1970))-\(week.weekNum)-\(dayIndex)"
    }

    func toggleDone(_ week: PublishedWeek, dayIndex: Int) {
        let key = dayKey(week, dayIndex: dayIndex)
        if doneDays.contains(key) { doneDays.remove(key) } else { doneDays.insert(key) }
        Self.saveJSON(doneDays, "done-days.json")
    }

    // MARK: disk cache

    private static var cacheDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private static func saveJSON<T: Encodable>(_ value: T, _ name: String) {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try? enc.encode(value).write(to: cacheDir.appendingPathComponent(name), options: .atomic)
    }

    private static func loadJSON<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: cacheDir.appendingPathComponent(name)) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: data)
    }
}

/// Minimal Keychain wrapper — iOS apps own their keychain, no prompts.
enum Keychain {
    private static let service = "com.peakweek.client"
    private static let account = "device-token"

    static func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func setToken(_ token: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
