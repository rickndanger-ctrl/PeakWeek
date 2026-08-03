import Foundation

// MARK: - Core enums

enum Unit: String, Codable, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    var step: Double { self == .kg ? 2.5 : 5 }
}

enum Phase: String, Codable {
    case acc, trans, real, deload, meet, hyp

    var label: String {
        switch self {
        case .acc: return "Accumulation"
        case .trans: return "Transmutation"
        case .real: return "Realization"
        case .deload: return "Deload"
        case .meet: return "Meet Week"
        case .hyp: return "Hypertrophy"
        }
    }
    var sub: String {
        switch self {
        case .acc: return "Volume · Hypertrophy"
        case .trans: return "Strength"
        case .real: return "Peaking"
        case .deload: return "Recovery"
        case .meet: return "Platform"
        case .hyp: return "Muscle · Off-Season"
        }
    }
    var blurb: String {
        switch self {
        case .acc: return "Build muscle and work capacity. Highest volume of the plan — moderate loads, big sets, plenty of variation and accessory work. Main-lift load climbs linearly every week."
        case .trans: return "Convert new muscle into maximal strength. Reps drop to 3–5, volume comes down ~30%, exercise selection narrows toward the comp lifts. Load climbs ~2–3% per week."
        case .real: return "Shed fatigue and sharpen. Heavy singles and doubles at 87–93%, volume cut hard. Openers taken 7–10 days out; last heavy deadlift 10–14 days out."
        case .deload: return "Planned recovery week. Volume cut roughly in half, intensity moderate. Adaptation happens here."
        case .meet: return "Light technique work early, then rest. You cannot gain strength this week — you can only lose fatigue."
        case .hyp: return "Build muscle now, convert it to strength later. Close variations of the comp lifts at higher reps and moderate loads, accessory volume roughly doubled, reps stepping down and weights up across each block. Re-test your max before the next strength block."
        }
    }
}

enum StartPhase: String, Codable, CaseIterable, Identifiable {
    case full, acc, trans, real, offseason, hypertrophy
    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: return "Full meet prep (all 3 phases)"
        case .acc: return "Accumulation only (volume)"
        case .trans: return "Strength block only"
        case .real: return "Peaking block only"
        case .offseason: return "Off-season (volume + strength)"
        case .hypertrophy: return "Hypertrophy off-season (build)"
        }
    }
    var minWeeks: Int {
        switch self {
        case .full: return 10
        case .acc, .trans: return 4
        case .real: return 3
        case .offseason, .hypertrophy: return 8
        }
    }
    var maxWeeks: Int {
        switch self {
        case .full: return 16
        case .acc, .trans: return 6
        case .real: return 4
        case .offseason, .hypertrophy: return 12
        }
    }
    var defaultWeeks: Int {
        switch self {
        case .full: return 12
        case .acc, .trans: return 5
        case .real: return 3
        case .offseason: return 10
        case .hypertrophy: return 12
        }
    }
}

/// Per-phase progression scheme — the coach picks these MANUALLY (never
/// auto-applied). Linear is the factory behavior.
enum PhaseScheme: String, Codable, CaseIterable, Identifiable {
    case linear, wave, dup, rpeAnchored
    var id: String { rawValue }
    var label: String {
        switch self {
        case .linear: return "Linear (classic)"
        case .wave: return "Wave (3-week waves)"
        case .dup: return "Undulating (DUP)"
        case .rpeAnchored: return "Linear — RPE-anchored (72–80%)"
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

/// Coach-chosen phase lengths for a full meet prep. nil on a client means the
/// engine's automatic allocation (factory behavior, unchanged).
struct BlockPlan: Codable, Hashable {
    var acc: Int = 4              // volume weeks
    var deloadAfterAcc: Bool = true
    var trans: Int = 4            // strength weeks
    var real: Int = 3             // peaking weeks INCLUDING meet week
    /// Manual scheme choices (composability: schemes attach to phases).
    var accScheme: PhaseScheme = .linear
    var transScheme: PhaseScheme = .linear
    /// RPE-anchored band override — the coach matches the entry point to
    /// whatever program the lifter is transitioning FROM (nil = 72→80 sixes;
    /// bench eights derive as entry−3 → top−5).
    var accBandLo: Double? = nil
    var accBandHi: Double? = nil

    // The deload only exists when there's a volume block for it to follow.
    var total: Int { acc + (acc > 0 && deloadAfterAcc ? 1 : 0) + trans + real }

    init() {}
    init(acc: Int, deloadAfterAcc: Bool, trans: Int, real: Int,
         accScheme: PhaseScheme = .linear, transScheme: PhaseScheme = .linear) {
        self.acc = acc; self.deloadAfterAcc = deloadAfterAcc
        self.trans = trans; self.real = real
        self.accScheme = accScheme; self.transScheme = transScheme
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        acc = try c.decodeIfPresent(Int.self, forKey: .acc) ?? 4
        deloadAfterAcc = try c.decodeIfPresent(Bool.self, forKey: .deloadAfterAcc) ?? true
        trans = try c.decodeIfPresent(Int.self, forKey: .trans) ?? 4
        real = try c.decodeIfPresent(Int.self, forKey: .real) ?? 3
        accScheme = try c.decodeIfPresent(PhaseScheme.self, forKey: .accScheme) ?? .linear
        transScheme = try c.decodeIfPresent(PhaseScheme.self, forKey: .transScheme) ?? .linear
        accBandLo = try c.decodeIfPresent(Double.self, forKey: .accBandLo)
        accBandHi = try c.decodeIfPresent(Double.self, forKey: .accBandHi)
    }
}

struct Program: Codable, Hashable {
    var startPhase: StartPhase
    var totalWeeks: Int
    var fiveDay: Bool
    var createdAt: Date
    var blocks: [Block]
    var weeks: [Week]

    // MARK: structural editing (deload insertion/removal)

    /// Coach rule: deload weeks are NEVER back-to-back. True when inserting a
    /// deload at `index` keeps that invariant.
    func canInsertDeload(at index: Int) -> Bool {
        let i = min(max(0, index), weeks.count)
        if i > 0, weeks[i - 1].phase == .deload { return false }
        if i < weeks.count, weeks[i].phase == .deload { return false }
        return true
    }

    /// The transmutation → realization boundary (index of the first
    /// realization week) — where a pre-meet deload belongs.
    var realizationBoundary: Int? {
        weeks.firstIndex { $0.phase == .real }
    }

    /// Insert a deload week, refusing any position that would create two
    /// deloads in a row. Returns whether the insertion happened.
    @discardableResult
    mutating func insertDeload(week: Week, at index: Int) -> Bool {
        guard week.phase == .deload, canInsertDeload(at: index) else { return false }
        insert(week: week, at: index)
        return true
    }

    /// Insert a week at `index`; everything downstream adjusts: numbering,
    /// block grouping, per-week block coordinates, totals.
    mutating func insert(week: Week, at index: Int) {
        let i = min(max(0, index), weeks.count)
        weeks.insert(week, at: i)
        renumberAndRegroup()
    }

    /// Remove the week at `index` (callers restrict this to deload weeks so
    /// real training content can't be destroyed by a structural edit).
    mutating func removeWeek(at index: Int) {
        guard weeks.indices.contains(index) else { return }
        weeks.remove(at: index)
        renumberAndRegroup()
    }

    /// Recompute week numbers, block-run coordinates (weekInBlock/blockLen),
    /// the blocks array (run-length grouping of phases), and totalWeeks.
    mutating func renumberAndRegroup() {
        for i in weeks.indices { weeks[i].num = i + 1 }
        totalWeeks = weeks.count

        var runs: [(phase: Phase, range: Range<Int>)] = []
        var start = 0
        for i in weeks.indices {
            if i + 1 == weeks.count || weeks[i + 1].phase != weeks[i].phase {
                runs.append((weeks[start].phase, start..<(i + 1)))
                start = i + 1
            }
        }
        blocks = runs.map { Block(phase: $0.phase, weeks: $0.range.count) }
        for run in runs {
            for (offset, wi) in run.range.enumerated() {
                weeks[wi].weekInBlock = offset + 1
                weeks[wi].blockLen = run.range.count
            }
        }
    }
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

    static let lbPerKg = 2.204622621848776

    /// Exact unit conversion (no rounding — display formats; loads round at
    /// prescription time). Round-tripping lb→kg→lb returns the original values.
    func converted(from old: Unit, to new: Unit) -> Maxes {
        guard old != new else { return self }
        let f = new == .kg ? 1 / Self.lbPerKg : Self.lbPerKg
        return Maxes(squat: squat * f, bench: bench * f, deadlift: deadlift * f)
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
    var blockPlan: BlockPlan? = nil       // nil = automatic phase allocation
    /// Training styles — top-level coach choices, independent of custom
    /// lengths. Copied onto the generation plan at Generate time.
    var accScheme: PhaseScheme = .linear
    var transScheme: PhaseScheme = .linear
    var accBandLo: Double? = nil          // RPE-anchored entry override
    var accBandHi: Double? = nil

    init(id: UUID = UUID(), name: String, unit: Unit = .lb, maxes: Maxes = Maxes(),
         setupPhase: StartPhase = .full, setupWeeks: Int = 12, fiveDay: Bool = false,
         program: Program? = nil, startDate: Date? = nil, meetDate: Date? = nil,
         delivery: DeliveryPrefs = DeliveryPrefs(), settings: ClientSettings = ClientSettings(),
         blockPlan: BlockPlan? = nil,
         accScheme: PhaseScheme = .linear, transScheme: PhaseScheme = .linear) {
        self.id = id; self.name = name; self.unit = unit; self.maxes = maxes
        self.setupPhase = setupPhase; self.setupWeeks = setupWeeks; self.fiveDay = fiveDay
        self.program = program; self.startDate = startDate; self.meetDate = meetDate
        self.delivery = delivery; self.settings = settings; self.blockPlan = blockPlan
        self.accScheme = accScheme; self.transScheme = transScheme
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
        blockPlan = try c.decodeIfPresent(BlockPlan.self, forKey: .blockPlan)
        accScheme = try c.decodeIfPresent(PhaseScheme.self, forKey: .accScheme)
            ?? blockPlan?.accScheme ?? .linear      // migrate earlier plan-level choices
        transScheme = try c.decodeIfPresent(PhaseScheme.self, forKey: .transScheme)
            ?? blockPlan?.transScheme ?? .linear
        accBandLo = try c.decodeIfPresent(Double.self, forKey: .accBandLo) ?? blockPlan?.accBandLo
        accBandHi = try c.decodeIfPresent(Double.self, forKey: .accBandHi) ?? blockPlan?.accBandHi
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
        exerciseLibrary.mergeNewSeeds()     // seed additions reach existing libraries
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
