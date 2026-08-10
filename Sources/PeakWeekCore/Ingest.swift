import Foundation

/// One row of the inbound audit trail: a client submission as it arrived and
/// what happened to it. Mirrors SendRecord on the outbound side; drives the
/// Inbox review UI.
public struct IngestRecord: Codable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var submissionID: UUID
    public var clientID: UUID
    public var clientName: String
    public var date: Date                     // when it was ingested
    public var performedAt: Date              // when the lifter did the set
    public var summary: String                // "Deadlift 315×3 @8"
    public var flags: [String] = []
    public var videoFilename: String? = nil
    public var state: State = .new
    /// What kind of inbound item: a logged SET (creates a log entry) or a
    /// free-text NOTE to the coach (inbox-only, always notifies).
    /// nil decodes as .set — every pre-notes record was a set.
    public var kind: Kind? = nil

    public enum State: String, Codable {
        case new        // awaiting the coach's eyes
        case reviewed   // coach looked, data stands
        case dismissed  // coach rejected it — the log entry was removed
    }

    public enum Kind: String, Codable {
        case set, note
    }

    /// Effective kind — nil (pre-notes records) reads as a set.
    public var effectiveKind: Kind { kind ?? .set }

    public init(id: UUID = UUID(), submissionID: UUID, clientID: UUID,
         clientName: String, date: Date, performedAt: Date, summary: String,
         flags: [String] = [], videoFilename: String? = nil,
         state: State = .new, kind: Kind? = nil) {
        self.id = id; self.submissionID = submissionID; self.clientID = clientID
        self.clientName = clientName; self.date = date
        self.performedAt = performedAt; self.summary = summary
        self.flags = flags; self.videoFilename = videoFilename
        self.state = state; self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        submissionID = try c.decode(UUID.self, forKey: .submissionID)
        clientID = try c.decode(UUID.self, forKey: .clientID)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName) ?? "Client"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        performedAt = try c.decodeIfPresent(Date.self, forKey: .performedAt) ?? date
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        flags = try c.decodeIfPresent([String].self, forKey: .flags) ?? []
        videoFilename = try c.decodeIfPresent(String.self, forKey: .videoFilename)
        state = try c.decodeIfPresent(State.self, forKey: .state) ?? .new
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind)
    }
}

/// A free-text note from the client app — no lift attached. Wire type from
/// the pipe; the id is client-generated and idempotent like submissions.
public struct ClientNote: Codable, Identifiable, Hashable {
    public var id: UUID
    public var clientID: UUID
    public var body: String
    public var createdAt: Date

    public init(id: UUID = UUID(), clientID: UUID, body: String,
                createdAt: Date = Date()) {
        self.id = id; self.clientID = clientID
        self.body = body; self.createdAt = createdAt
    }
}

public enum Ingest {
    /// "Deadlift 315×3 @8 — hips shot up" — the one-line human summary for
    /// inbox rows and notifications. Load shown in the CLIENT'S unit
    /// (post-conversion). A note the lifter attached to the set is appended:
    /// it is the most coaching-relevant thing in the payload and must never
    /// be buried.
    public static func summary(for entry: LiftLogEntry, unit: Unit) -> String {
        let name = entry.exerciseName ?? entry.lift.groupLabel.capitalized
        var s = "\(name) \(Engine.loadString(entry.load, unit: unit))×\(entry.reps)"
        if let r = entry.rpe {
            s += r == r.rounded() ? " @\(Int(r))" : String(format: " @%.1f", r)
        }
        let note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { s += " — \(note)" }
        return s
    }

    /// Build the log entry a submission becomes: load converted EXACTLY from
    /// the declared payload unit into the client's unit (same math as
    /// Maxes.converted — lossless round-trip), provenance stamped.
    public static func entry(from sub: Submission, clientUnit: Unit) -> LiftLogEntry {
        let load: Double
        if sub.unit == clientUnit {
            load = sub.load
        } else {
            load = sub.load * (clientUnit == .kg ? 1 / Maxes.lbPerKg : Maxes.lbPerKg)
        }
        return LiftLogEntry(date: sub.performedAt, lift: sub.lift,
                            exerciseName: sub.exerciseName,
                            load: load, reps: sub.reps, rpe: sub.rpe,
                            prescribedPct: sub.prescribedPct,
                            prescribedRPE: sub.prescribedRPE,
                            weekNum: sub.weekNum,
                            programStamp: sub.programStamp,
                            note: sub.note?.trimmingCharacters(in: .whitespaces) ?? "",
                            source: .client, submissionID: sub.id)
    }
}
