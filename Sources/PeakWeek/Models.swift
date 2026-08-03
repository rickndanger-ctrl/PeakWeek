import Foundation

// MARK: - Core enums

enum Unit: String, Codable, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    var step: Double { self == .kg ? 2.5 : 5 }
}

enum Phase: String, Codable {
    case acc, trans, real, deload, meet

    var label: String {
        switch self {
        case .acc: return "Accumulation"
        case .trans: return "Transmutation"
        case .real: return "Realization"
        case .deload: return "Deload"
        case .meet: return "Meet Week"
        }
    }
    var sub: String {
        switch self {
        case .acc: return "Volume · Hypertrophy"
        case .trans: return "Strength"
        case .real: return "Peaking"
        case .deload: return "Recovery"
        case .meet: return "Platform"
        }
    }
    var blurb: String {
        switch self {
        case .acc: return "Build muscle and work capacity. Highest volume of the plan — moderate loads, big sets, plenty of variation and accessory work. Main-lift load climbs linearly every week."
        case .trans: return "Convert new muscle into maximal strength. Reps drop to 3–5, volume comes down ~30%, exercise selection narrows toward the comp lifts. Load climbs ~2–3% per week."
        case .real: return "Shed fatigue and sharpen. Heavy singles and doubles at 87–93%, volume cut hard. Openers taken 7–10 days out; last heavy deadlift 10–14 days out."
        case .deload: return "Planned recovery week. Volume cut roughly in half, intensity moderate. Adaptation happens here."
        case .meet: return "Light technique work early, then rest. You cannot gain strength this week — you can only lose fatigue."
        }
    }
}

enum StartPhase: String, Codable, CaseIterable, Identifiable {
    case full, acc, trans, real, offseason
    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: return "Full meet prep (all 3 phases)"
        case .acc: return "Accumulation only (volume)"
        case .trans: return "Strength block only"
        case .real: return "Peaking block only"
        case .offseason: return "Off-season (volume + strength)"
        }
    }
    var minWeeks: Int {
        switch self {
        case .full: return 10
        case .acc, .trans: return 4
        case .real: return 3
        case .offseason: return 8
        }
    }
    var maxWeeks: Int {
        switch self {
        case .full: return 16
        case .acc, .trans: return 6
        case .real: return 4
        case .offseason: return 12
        }
    }
    var defaultWeeks: Int {
        switch self {
        case .full: return 12
        case .acc, .trans: return 5
        case .real: return 3
        case .offseason: return 10
        }
    }
}

enum LiftPool: String, Codable, CaseIterable, Identifiable {
    case squat, bench, deadlift, quads, hams, back, press
    var id: String { rawValue }
    var groupLabel: String {
        switch self {
        case .squat: return "SQUAT"
        case .bench: return "BENCH"
        case .deadlift: return "DEADLIFT"
        case .quads: return "QUADS"
        case .hams: return "HAMS / HIPS"
        case .back: return "UPPER BACK"
        case .press: return "PRESS / TRICEPS"
        }
    }
}

// MARK: - Exercise catalogue

struct Exercise {
    let name: String
    let mod: Double?   // load modifier vs comp-lift 1RM; nil = accessory (RPE only)
}

// MARK: - Program structures (all Codable, saved to disk)

struct Slot: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var pool: LiftPool
    var exIdx: Int
    var custom: String? = nil     // non-nil = free-typed exercise name
    var sets: Int
    var reps: Int
    var pct: Double? = nil        // nil = accessory (no % / no computed load)
    var rpe: Double
}

struct DayPlan: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var slots: [Slot]
}

struct Week: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var num: Int
    var phase: Phase
    var weekInBlock: Int
    var blockLen: Int
    var note: String = ""
    var days: [DayPlan]
}

struct Block: Codable, Hashable {
    var phase: Phase
    var weeks: Int
}

struct Program: Codable, Hashable {
    var startPhase: StartPhase
    var totalWeeks: Int
    var fiveDay: Bool
    var createdAt: Date
    var blocks: [Block]
    var weeks: [Week]
}

struct Maxes: Codable, Hashable {
    var squat: Double = 0
    var bench: Double = 0
    var deadlift: Double = 0

    func value(for pool: LiftPool) -> Double {
        switch pool {
        case .squat: return squat
        case .bench: return bench
        case .deadlift: return deadlift
        default: return 0
        }
    }
}

struct Client: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var unit: Unit = .lb
    var maxes: Maxes = Maxes()
    var setupPhase: StartPhase = .full
    var setupWeeks: Int = 12
    var fiveDay: Bool = false
    var program: Program? = nil
}

struct AppData: Codable {
    var clients: [Client] = []
}
