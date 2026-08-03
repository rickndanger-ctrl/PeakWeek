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
    var exIdx: Int? = nil         // legacy seed index; migrated to exerciseID on load
    var exerciseID: UUID? = nil   // canonical library reference
    var custom: String? = nil     // non-nil = free-typed exercise name
    var sets: Int
    var reps: Int
    var pct: Double? = nil        // nil = accessory (no % / no computed load)
    var rpe: Double
    var note: String? = nil       // optional per-slot coach cue
    var filmThis: Bool? = nil     // "film this set" flag
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
    var startDate: Date? = nil            // Monday of program week 1
    var meetDate: Date? = nil             // optional: drives weeks-out display
    var delivery: DeliveryPrefs = DeliveryPrefs()
    var settings: ClientSettings = ClientSettings()

    init(id: UUID = UUID(), name: String, unit: Unit = .lb, maxes: Maxes = Maxes(),
         setupPhase: StartPhase = .full, setupWeeks: Int = 12, fiveDay: Bool = false,
         program: Program? = nil, startDate: Date? = nil, meetDate: Date? = nil,
         delivery: DeliveryPrefs = DeliveryPrefs(), settings: ClientSettings = ClientSettings()) {
        self.id = id; self.name = name; self.unit = unit; self.maxes = maxes
        self.setupPhase = setupPhase; self.setupWeeks = setupWeeks; self.fiveDay = fiveDay
        self.program = program; self.startDate = startDate; self.meetDate = meetDate
        self.delivery = delivery; self.settings = settings
    }

    // Tolerant decoding: fields added after v1 fall back to defaults so old
    // data.json files (and backups) always open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        unit = try c.decodeIfPresent(Unit.self, forKey: .unit) ?? .lb
        maxes = try c.decodeIfPresent(Maxes.self, forKey: .maxes) ?? Maxes()
        setupPhase = try c.decodeIfPresent(StartPhase.self, forKey: .setupPhase) ?? .full
        setupWeeks = try c.decodeIfPresent(Int.self, forKey: .setupWeeks) ?? 12
        fiveDay = try c.decodeIfPresent(Bool.self, forKey: .fiveDay) ?? false
        program = try c.decodeIfPresent(Program.self, forKey: .program)
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        meetDate = try c.decodeIfPresent(Date.self, forKey: .meetDate)
        delivery = try c.decodeIfPresent(DeliveryPrefs.self, forKey: .delivery) ?? DeliveryPrefs()
        settings = try c.decodeIfPresent(ClientSettings.self, forKey: .settings) ?? ClientSettings()
    }
}

struct AppData: Codable {
    var schemaVersion: Int = 3      // absent in v1 files → decodes as 1
    var clients: [Client] = []
    var sendLog: [SendRecord] = []
    var exerciseLibrary: ExerciseLibrary = .seeded()

    init(clients: [Client] = [], sendLog: [SendRecord] = [],
         exerciseLibrary: ExerciseLibrary = .seeded()) {
        self.clients = clients
        self.sendLog = sendLog
        self.exerciseLibrary = exerciseLibrary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        clients = try c.decodeIfPresent([Client].self, forKey: .clients) ?? []
        sendLog = try c.decodeIfPresent([SendRecord].self, forKey: .sendLog) ?? []
        exerciseLibrary = try c.decodeIfPresent(ExerciseLibrary.self, forKey: .exerciseLibrary) ?? .seeded()
        migrateSlotReferences()
        schemaVersion = 3           // decoding IS the migration
    }

    /// v2 → v3: fill canonical exerciseIDs from legacy (pool, exIdx) seed
    /// references. Never drops a slot — unresolvable refs become custom text.
    private mutating func migrateSlotReferences() {
        for ci in clients.indices {
            guard clients[ci].program != nil else { continue }
            for wi in clients[ci].program!.weeks.indices {
                for di in clients[ci].program!.weeks[wi].days.indices {
                    for si in clients[ci].program!.weeks[wi].days[di].slots.indices {
                        var slot = clients[ci].program!.weeks[wi].days[di].slots[si]
                        guard slot.custom == nil, slot.exerciseID == nil else { continue }
                        if let idx = slot.exIdx,
                           let hit = exerciseLibrary.seeded("\(slot.pool.rawValue):\(idx)") {
                            slot.exerciseID = hit.id
                        } else {
                            slot.custom = "Exercise"   // unresolvable: keep the slot, lose only the link
                        }
                        clients[ci].program!.weeks[wi].days[di].slots[si] = slot
                    }
                }
            }
        }
    }
}
