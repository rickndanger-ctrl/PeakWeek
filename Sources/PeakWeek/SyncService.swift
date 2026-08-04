import Foundation
import Security

/// The Mac side of the client-app pipe. Plain HTTPS to the peakweek-api
/// edge function; the anon key satisfies the gateway, the real credential
/// is the coach token in the macOS Keychain (hashed server-side).
///
/// Poll → ingest (idempotent) → download videos → ACK. Ack comes last, only
/// for submissions whose local state is durable — the server deletes cloud
/// video objects on ack, so nothing is removed until it's safe here.
enum SyncService {

    static let baseURL = URL(string: "https://zfelhehlwglvakpaelrj.supabase.co/functions/v1/peakweek-api")!
    /// Public by design: RLS is enabled with zero policies, so this key alone
    /// grants nothing — it only satisfies the function gateway.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZWxoZWhsd2dsdmFrcGFlbHJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NzY4NjYsImV4cCI6MjA5OTA1Mjg2Nn0.-bYE3dMeAc26J9HtH-1LIt94DdTT2AOM_lPF0xMS1_Q"

    // MARK: coach credential

    /// Token file beside data.json, mode 0600 — the same protection class as
    /// the client data it guards. (Keychain ACLs don't survive ad-hoc
    /// re-signing: every redeploy re-prompted. The file never does.)
    static var tokenURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeakWeek/sync-token")
    }

    private static var cachedToken: String??

    static func coachToken() -> String? {
        if let cached = cachedToken { return cached }
        let token = (try? String(contentsOf: tokenURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let result = (token?.isEmpty == false) ? token : nil
        cachedToken = result
        return result
    }

    static var isConfigured: Bool { coachToken() != nil }

    // MARK: plumbing

    private static func request(_ path: String, method: String = "GET",
                                body: [String: Any]? = nil) async throws -> (Data, Int) {
        guard let token = coachToken() else {
            throw NSError(domain: "PeakWeekSync", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "no coach token in Keychain"])
        }
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue(token, forHTTPHeaderField: "X-PW-Token")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }

    /// Postgres timestamps come back with fractional seconds; plain ISO8601
    /// parsing must not choke on either form.
    static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dec.dateDecodingStrategy = .custom { d in
            let s = try d.singleValueContainer().decode(String.self)
            if let date = fractional.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath,
                                                    debugDescription: "bad date \(s)"))
        }
        return dec
    }()

    /// Wire row from /admin/inbox (snake_case server columns).
    struct SubmissionRow: Codable {
        var id: UUID
        var clientId: UUID
        var performedAt: Date
        var lift: String
        var exerciseName: String?
        var load: Double
        var unit: String
        var reps: Int
        var rpe: Double?
        var prescribedPct: Double?
        var prescribedRpe: Double?
        var weekNum: Int?
        var programStamp: Date?
        var note: String?
        var videoPath: String?
        var videoStatus: String

        enum CodingKeys: String, CodingKey {
            case id, lift, load, unit, reps, rpe, note
            case clientId = "client_id"
            case performedAt = "performed_at"
            case exerciseName = "exercise_name"
            case prescribedPct = "prescribed_pct"
            case prescribedRpe = "prescribed_rpe"
            case weekNum = "week_num"
            case programStamp = "program_stamp"
            case videoPath = "video_path"
            case videoStatus = "video_status"
        }

        func asSubmission() -> Submission? {
            guard let liftPool = LiftPool(rawValue: lift),
                  let u = Unit(rawValue: unit) else { return nil }
            return Submission(id: id, clientID: clientId, performedAt: performedAt,
                              lift: liftPool, exerciseName: exerciseName,
                              load: load, unit: u, reps: reps, rpe: rpe,
                              prescribedPct: prescribedPct, prescribedRPE: prescribedRpe,
                              weekNum: weekNum, programStamp: programStamp,
                              note: note,
                              videoFilename: videoPath != nil ? "\(id.uuidString).mp4" : nil)
        }
    }

    // MARK: video storage

    static var videosRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PeakWeek/Videos", isDirectory: true)
    }

    static func localVideoURL(clientID: UUID, submissionID: UUID) -> URL {
        videosRoot.appendingPathComponent(clientID.uuidString, isDirectory: true)
            .appendingPathComponent("\(submissionID.uuidString).mp4")
    }

    private static func downloadVideo(path: String, clientID: UUID,
                                      submissionID: UUID) async -> Bool {
        do {
            let (data, status) = try await request("admin/video-url", method: "POST",
                                                   body: ["path": path])
            guard status == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlStr = obj["url"] as? String,
                  let url = URL(string: urlStr) else { return false }
            let (bytes, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let dest = localVideoURL(clientID: clientID, submissionID: submissionID)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try bytes.write(to: dest, options: .atomic)
            return true
        } catch {
            NSLog("PeakWeek sync: video download failed — %@", String(describing: error))
            return false
        }
    }

    // MARK: the poll

    /// One full inbox pass. Safe to call repeatedly; everything is idempotent.
    @discardableResult
    static func pollInbox(store: AppStore) async -> Int {
        guard isConfigured else { return 0 }
        let frozen = await MainActor.run { store.loadFailed }
        guard !frozen else { return 0 }

        let rows: [SubmissionRow]
        do {
            let (data, status) = try await request("admin/inbox")
            guard status == 200 else {
                NSLog("PeakWeek sync: inbox returned %d", status)
                return 0
            }
            struct Wrapper: Codable { var submissions: [SubmissionRow] }
            rows = try decoder.decode(Wrapper.self, from: data).submissions
        } catch {
            NSLog("PeakWeek sync: inbox fetch failed — %@", String(describing: error))
            return 0
        }
        guard !rows.isEmpty else { return 0 }

        var ackIDs: [String] = []
        var ingested = 0
        for row in rows {
            guard let sub = row.asSubmission() else {
                ackIDs.append(row.id.uuidString)   // malformed: ack so it stops looping
                continue
            }
            // Ingest on the main actor (mutates store.data). nil = duplicate
            // or unknown client — both safe to ack (duplicate already durable;
            // unknown client can never ingest and must not loop forever).
            let record = await MainActor.run { store.ingest(sub) }
            if record != nil { ingested += 1 }

            // Video: secure it locally BEFORE ack (ack deletes the cloud copy).
            if let path = row.videoPath, row.videoStatus == "uploaded" {
                let ok = await downloadVideo(path: path, clientID: row.clientId,
                                             submissionID: row.id)
                if !ok { continue }   // no ack — retried next poll, idempotent
            } else if row.videoPath != nil, row.videoStatus == "pending" {
                // Upload still in flight from the phone: give it a cycle.
                continue
            }
            ackIDs.append(row.id.uuidString)
        }

        if !ackIDs.isEmpty {
            _ = try? await request("admin/ack", method: "POST", body: ["ids": ackIDs])
        }
        return ingested
    }

    // MARK: publish (fire-and-forget on every successful send)

    static func publishWeek(client: Client, program: Program, week: Week,
                            library: ExerciseLibrary) {
        guard isConfigured else { return }
        let published = Engine.weekToPublished(client: client, program: program,
                                               week: week, library: library)
        Task.detached(priority: .utility) {
            do {
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .iso8601
                let payloadData = try enc.encode(published)
                let payload = try JSONSerialization.jsonObject(with: payloadData)
                let iso = ISO8601DateFormatter()
                let body: [String: Any] = [
                    "client_id": client.id.uuidString,
                    "name": client.name,
                    "unit": client.unit.rawValue,
                    "week_num": week.num,
                    "program_stamp": iso.string(from: program.createdAt),
                    "payload": payload,
                ]
                let (_, status) = try await request("admin/publish-week",
                                                    method: "POST", body: body)
                if status != 200 { NSLog("PeakWeek sync: publish returned %d", status) }
            } catch {
                NSLog("PeakWeek sync: publish failed — %@", String(describing: error))
            }
        }
    }

    // MARK: pairing

    static func mintPairingCode(for client: Client) async throws -> String {
        let (data, status) = try await request("admin/pairing-codes", method: "POST",
                                               body: ["client_id": client.id.uuidString,
                                                      "name": client.name,
                                                      "unit": client.unit.rawValue])
        guard status == 200,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = obj["code"] as? String else {
            throw NSError(domain: "PeakWeekSync", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "pairing-code request failed (\(status))"])
        }
        return code
    }

    static func unpair(clientID: UUID) async {
        _ = try? await request("admin/unpair", method: "POST",
                               body: ["client_id": clientID.uuidString])
    }

    /// Settings "Test connection": true when the inbox route answers 200.
    static func testConnection() async -> Bool {
        guard isConfigured else { return false }
        let result = try? await request("admin/inbox")
        return result?.1 == 200
    }

    /// Local video retention: keep 90 days, sweep alongside the delivery pass.
    static func cleanupVideoStorage(olderThanDays days: Double = 90) {
        let cutoff = Date().addingTimeInterval(-days * 86400)
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: videosRoot,
                                                     includingPropertiesForKeys: nil) else { return }
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for f in files {
                if let mod = try? f.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate, mod < cutoff {
                    try? fm.removeItem(at: f)
                }
            }
            if (try? fm.contentsOfDirectory(atPath: dir.path))?.isEmpty == true {
                try? fm.removeItem(at: dir)
            }
        }
    }
}
