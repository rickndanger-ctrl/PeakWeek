import Foundation

// MARK: - Per-client coaching customization
// Everything here defaults to nil / factory behavior: a client with no
// settings programs EXACTLY like the engine always has.

public struct AttemptProfile: Codable, Hashable {
    public enum Risk: String, Codable, CaseIterable, Identifiable {
        case conservative, standard, aggressive
        public var id: String { rawValue }
        public var label: String { rawValue.capitalized }
    }

    public var risk: Risk = .standard
    public var opener: Double? = nil     // explicit % overrides beat the risk preset
    public var second: Double? = nil
    public var third: Double? = nil

    public init(risk: Risk = .standard, opener: Double? = nil,
                second: Double? = nil, third: Double? = nil) {
        self.risk = risk; self.opener = opener
        self.second = second; self.third = third
    }

    /// Preset percentages per risk level. Standard is the engine's trusted
    /// 91 / 97 / 101.5. Ranges per research (Report 1 §6.3).
    /// Overrides are clamped 80–115% here so a half-typed value in the UI can
    /// never produce an absurd attempt.
    public var effective: (opener: Double, second: Double, third: Double) {
        let base: (Double, Double, Double)
        switch risk {
        case .conservative: base = (89.5, 94.5, 100.0)
        case .standard:     base = (91.0, 97.0, 101.5)
        case .aggressive:   base = (92.5, 97.5, 104.0)
        }
        func clamp(_ v: Double?) -> Double? { v.map { min(115, max(80, $0)) } }
        return (clamp(opener) ?? base.0, clamp(second) ?? base.1, clamp(third) ?? base.2)
    }

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        risk = try c.decodeIfPresent(Risk.self, forKey: .risk) ?? .standard
        opener = try c.decodeIfPresent(Double.self, forKey: .opener)
        second = try c.decodeIfPresent(Double.self, forKey: .second)
        third = try c.decodeIfPresent(Double.self, forKey: .third)
    }
}

public struct LiftSettings: Codable, Hashable {
    /// Program off a percentage of the entered 1RM (e.g. 95 = 95% training max).
    public var trainingMaxPct: Double? = nil
    /// Additive percentage-point offset for every prescription of this lift.
    public var intensityOffset: Double? = nil

    public init(trainingMaxPct: Double? = nil, intensityOffset: Double? = nil) {
        self.trainingMaxPct = trainingMaxPct; self.intensityOffset = intensityOffset
    }
}

public struct ClientSettings: Codable, Hashable {
    public var attempts: AttemptProfile? = nil
    public var perLift: [String: LiftSettings]? = nil      // keyed by pool rawValue
    public var excludedExerciseIDs: Set<UUID>? = nil
    public var notes: String? = nil

    public init(attempts: AttemptProfile? = nil,
                perLift: [String: LiftSettings]? = nil,
                excludedExerciseIDs: Set<UUID>? = nil, notes: String? = nil) {
        self.attempts = attempts; self.perLift = perLift
        self.excludedExerciseIDs = excludedExerciseIDs; self.notes = notes
    }

    public func lift(_ pool: LiftPool) -> LiftSettings {
        perLift?[pool.rawValue] ?? LiftSettings()
    }

    public var isCustomized: Bool {
        (attempts != nil && attempts != AttemptProfile())
        || perLift?.values.contains { $0.trainingMaxPct != nil || $0.intensityOffset != nil } == true
        || !(excludedExerciseIDs?.isEmpty ?? true)
        || !(notes?.isEmpty ?? true)
    }

    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try c.decodeIfPresent(AttemptProfile.self, forKey: .attempts)
        perLift = try c.decodeIfPresent([String: LiftSettings].self, forKey: .perLift)
        excludedExerciseIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .excludedExerciseIDs)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}
