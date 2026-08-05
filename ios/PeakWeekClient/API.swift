import Foundation
import PeakWeekCore

/// Device-token client for the peakweek-api pipe. The anon key satisfies the
/// gateway; the real credential is the device token minted at pairing.
enum API {
    static let baseURL = URL(string: "https://zfelhehlwglvakpaelrj.supabase.co/functions/v1/peakweek-api")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmZWxoZWhsd2dsdmFrcGFlbHJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NzY4NjYsImV4cCI6MjA5OTA1Mjg2Nn0.-bYE3dMeAc26J9HtH-1LIt94DdTT2AOM_lPF0xMS1_Q"

    struct PairedClient: Codable {
        var id: UUID
        var name: String
        var unit: String
    }

    struct WeekEnvelope: Codable {
        var weekNum: Int?
        var payload: PublishedWeek?
        var publishedAt: Date?

        enum CodingKeys: String, CodingKey {
            case weekNum = "week_num"
            case payload
            case publishedAt = "published_at"
        }
    }

    struct MineRow: Codable, Identifiable {
        var id: UUID
        var performedAt: Date
        var lift: String
        var load: Double
        var unit: String
        var reps: Int
        var rpe: Double?
        var status: String
        var videoStatus: String

        enum CodingKeys: String, CodingKey {
            case id, lift, load, unit, reps, rpe, status
            case performedAt = "performed_at"
            case videoStatus = "video_status"
        }
    }

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

    private static func request(_ path: String, method: String = "GET",
                                token: String?, body: [String: Any]? = nil)
        async throws -> (Data, Int) {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        if let token { req.setValue(token, forHTTPHeaderField: "X-PW-Token") }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
    }

    // MARK: pairing

    static func pair(code: String, deviceName: String) async throws -> (token: String, client: PairedClient) {
        let (data, status) = try await request("pair", method: "POST", token: nil,
                                               body: ["code": code, "deviceName": deviceName])
        guard status == 200 else {
            throw APIError(message: status == 401
                           ? "That code isn't valid — ask your coach for a fresh one."
                           : "Pairing failed (\(status)). Try again.")
        }
        struct PairResponse: Codable { var token: String; var client: PairedClient }
        let resp = try decoder.decode(PairResponse.self, from: data)
        return (resp.token, resp.client)
    }

    // MARK: week

    static func fetchWeek(token: String) async throws -> WeekEnvelope? {
        let (data, status) = try await request("week", token: token)
        guard status == 200 else { throw APIError(message: "Couldn't reach your coach's system (\(status)).") }
        struct Wrapper: Codable { var week: WeekEnvelope? }
        return try decoder.decode(Wrapper.self, from: data).week
    }

    // MARK: submissions

    struct UploadTicket: Codable {
        var url: String
        var token: String
        var path: String
    }

    /// Returns the video upload ticket when the server expects one.
    static func submit(_ pending: PendingSubmission, token: String) async throws -> UploadTicket? {
        let iso = ISO8601DateFormatter()
        var body: [String: Any] = [
            "id": pending.id.uuidString,
            "performed_at": iso.string(from: pending.performedAt),
            "lift": pending.lift,
            "load": pending.load,
            "unit": pending.unit,
            "reps": pending.reps,
            "has_video": pending.videoLocalPath != nil,
        ]
        if let v = pending.rpe { body["rpe"] = v }
        if let v = pending.prescribedPct { body["prescribed_pct"] = v }
        if let v = pending.prescribedRPE { body["prescribed_rpe"] = v }
        if let v = pending.weekNum { body["week_num"] = v }
        if let v = pending.programStamp { body["program_stamp"] = iso.string(from: v) }
        if let v = pending.note, !v.isEmpty { body["note"] = v }
        if let v = pending.exerciseName { body["exercise_name"] = v }

        let (data, status) = try await request("submissions", method: "POST",
                                               token: token, body: body)
        guard status == 200 else { throw APIError(message: "Send failed (\(status)) — kept in your outbox.") }
        struct SubmitResponse: Codable { var ok: Bool; var upload: UploadTicket? }
        return try decoder.decode(SubmitResponse.self, from: data).upload
    }

    static func uploadVideo(fileURL: URL, ticket: UploadTicket) async throws {
        guard let url = URL(string: ticket.url) else { throw APIError(message: "bad upload URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 300
        let (_, resp) = try await URLSession.shared.upload(for: req, fromFile: fileURL)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw APIError(message: "Video upload failed (\(status)) — will retry.")
        }
    }

    static func videoDone(submissionID: UUID, token: String) async {
        _ = try? await request("submissions/video-done", method: "POST", token: token,
                               body: ["id": submissionID.uuidString])
    }

    static func postNote(id: UUID, body: String, token: String) async throws {
        let (_, status) = try await request("notes", method: "POST", token: token,
                                            body: ["id": id.uuidString, "body": body])
        guard status == 200 else { throw APIError(message: "Note send failed (\(status)) — kept in your outbox.") }
    }

    static func mine(token: String) async throws -> [MineRow] {
        let (data, status) = try await request("submissions/mine", token: token)
        guard status == 200 else { throw APIError(message: "Couldn't load history (\(status)).") }
        struct Wrapper: Codable { var submissions: [MineRow] }
        return try decoder.decode(Wrapper.self, from: data).submissions
    }
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
