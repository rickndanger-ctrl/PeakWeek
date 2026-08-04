import Foundation

/// The wire shape of one client-app submission — exactly what the phone
/// sends. The `id` is CLIENT-GENERATED and is the end-to-end idempotency
/// key: the server upserts on it, and ingest skips any submission whose id
/// already appears in the client's log. The unit always travels EXPLICITLY;
/// loads are never pre-converted in transit.
struct Submission: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var clientID: UUID
    var performedAt: Date
    var lift: LiftPool                 // squat / bench / deadlift
    var exerciseName: String? = nil    // nil = comp lift
    var load: Double
    var unit: Unit                     // the unit the lifter typed in
    var reps: Int
    var rpe: Double? = nil
    var prescribedPct: Double? = nil   // carried from the published week's slot
    var prescribedRPE: Double? = nil
    var weekNum: Int? = nil
    var programStamp: Date? = nil
    var note: String? = nil
    var videoFilename: String? = nil   // local filename once the video landed

    init(id: UUID = UUID(), clientID: UUID, performedAt: Date, lift: LiftPool,
         exerciseName: String? = nil, load: Double, unit: Unit, reps: Int,
         rpe: Double? = nil, prescribedPct: Double? = nil,
         prescribedRPE: Double? = nil, weekNum: Int? = nil,
         programStamp: Date? = nil, note: String? = nil,
         videoFilename: String? = nil) {
        self.id = id; self.clientID = clientID; self.performedAt = performedAt
        self.lift = lift; self.exerciseName = exerciseName
        self.load = load; self.unit = unit; self.reps = reps; self.rpe = rpe
        self.prescribedPct = prescribedPct; self.prescribedRPE = prescribedRPE
        self.weekNum = weekNum; self.programStamp = programStamp
        self.note = note; self.videoFilename = videoFilename
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        clientID = try c.decode(UUID.self, forKey: .clientID)
        performedAt = try c.decodeIfPresent(Date.self, forKey: .performedAt) ?? Date()
        lift = try c.decodeIfPresent(LiftPool.self, forKey: .lift) ?? .squat
        exerciseName = try c.decodeIfPresent(String.self, forKey: .exerciseName)
        load = try c.decodeIfPresent(Double.self, forKey: .load) ?? 0
        unit = try c.decodeIfPresent(Unit.self, forKey: .unit) ?? .lb
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 1
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        prescribedPct = try c.decodeIfPresent(Double.self, forKey: .prescribedPct)
        prescribedRPE = try c.decodeIfPresent(Double.self, forKey: .prescribedRPE)
        weekNum = try c.decodeIfPresent(Int.self, forKey: .weekNum)
        programStamp = try c.decodeIfPresent(Date.self, forKey: .programStamp)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        videoFilename = try c.decodeIfPresent(String.self, forKey: .videoFilename)
    }
}
