import Foundation

// MARK: - Per-client coaching customization
// Everything here defaults to nil / factory behavior: a client with no
// settings programs EXACTLY like the engine always has.

struct AttemptProfile: Codable, Hashable {
    enum Risk: String, Codable, CaseIterable, Identifiable {
        case conservative, standard, aggressive
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var risk: Risk = .standard
    var opener: Double? = nil     // explicit % overrides beat the risk preset
    var second: Double? = nil
    var third: Double? = nil

    /// Preset percentages per risk level. Standard is the engine's trusted
    /// 91 / 97 / 101.5. Ranges per research (Report 1 §6.3).
    var effective: (opener: Double, second: Double, third: Double) {
        let base: (Double, Double, Double)
        switch risk {
        case .conservative: base = (89.5, 94.5, 100.0)
        case .standard:     base = (91.0, 97.0, 101.5)
        case .aggressive:   base = (92.5, 97.5, 104.0)
        }
        return (opener ?? base.0, second ?? base.1, third ?? base.2)
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        risk = try c.decodeIfPresent(Risk.self, forKey: .risk) ?? .standard
        opener = try c.decodeIfPresent(Double.self, forKey: .opener)
        second = try c.decodeIfPresent(Double.self, forKey: .second)
        third = try c.decodeIfPresent(Double.self, forKey: .third)
    }
}

struct LiftSettings: Codable, Hashable {
    /// Program off a percentage of the entered 1RM (e.g. 95 = 95% training max).
    var trainingMaxPct: Double? = nil
    /// Additive percentage-point offset for every prescription of this lift.
    var intensityOffset: Double? = nil
}

struct ClientSettings: Codable, Hashable {
    var attempts: AttemptProfile? = nil
    var perLift: [String: LiftSettings]? = nil      // keyed by pool rawValue
    var excludedExerciseIDs: Set<UUID>? = nil
    var notes: String? = nil

    func lift(_ pool: LiftPool) -> LiftSettings {
        perLift?[pool.rawValue] ?? LiftSettings()
    }

    var isCustomized: Bool {
        (attempts != nil && attempts != AttemptProfile())
        || perLift?.values.contains { $0.trainingMaxPct != nil || $0.intensityOffset != nil } == true
        || !(excludedExerciseIDs?.isEmpty ?? true)
        || !(notes?.isEmpty ?? true)
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try c.decodeIfPresent(AttemptProfile.self, forKey: .attempts)
        perLift = try c.decodeIfPresent([String: LiftSettings].self, forKey: .perLift)
        excludedExerciseIDs = try c.decodeIfPresent(Set<UUID>.self, forKey: .excludedExerciseIDs)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}
