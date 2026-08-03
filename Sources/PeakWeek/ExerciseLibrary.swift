import Foundation

// MARK: - Editable exercise library
// Source of truth for exercises. Seeded from Engine's catalogue on first run;
// coaches add/rename/archive entries and edit load modifiers. Slots reference
// exercises by stable UUID so edits never corrupt saved programs.

struct LibraryExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var seedKey: String?      // "squat:0" … for built-ins; nil for coach-added
    var name: String
    var mod: Double?          // load modifier vs comp 1RM; nil = accessory (RPE-only)
    var archived: Bool = false

    init(id: UUID = UUID(), seedKey: String? = nil, name: String,
         mod: Double? = nil, archived: Bool = false) {
        self.id = id; self.seedKey = seedKey; self.name = name
        self.mod = mod; self.archived = archived
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        seedKey = try c.decodeIfPresent(String.self, forKey: .seedKey)
        name = try c.decode(String.self, forKey: .name)
        mod = try c.decodeIfPresent(Double.self, forKey: .mod)
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }
}

struct PoolEntries: Codable, Hashable, Identifiable {
    var pool: LiftPool
    var exercises: [LibraryExercise]
    var id: LiftPool { pool }
}

struct ExerciseLibrary: Codable, Hashable {
    var entries: [PoolEntries]

    /// Built from the engine's seed catalogue, preserving exact order so
    /// (pool, index) references map 1:1 onto seeded UUIDs.
    static func seeded() -> ExerciseLibrary {
        var out: [PoolEntries] = []
        for pool in LiftPool.allCases {
            let seeds = Engine.pools[pool] ?? []
            let exs = seeds.enumerated().map { i, ex in
                LibraryExercise(seedKey: "\(pool.rawValue):\(i)", name: ex.name, mod: ex.mod)
            }
            out.append(PoolEntries(pool: pool, exercises: exs))
        }
        return ExerciseLibrary(entries: out)
    }

    // MARK: lookup

    subscript(pool: LiftPool) -> [LibraryExercise] {
        get { entries.first { $0.pool == pool }?.exercises ?? [] }
        set {
            if let i = entries.firstIndex(where: { $0.pool == pool }) {
                entries[i].exercises = newValue
            } else {
                entries.append(PoolEntries(pool: pool, exercises: newValue))
            }
        }
    }

    func exercise(id: UUID) -> LibraryExercise? {
        for e in entries {
            if let hit = e.exercises.first(where: { $0.id == id }) { return hit }
        }
        return nil
    }

    func pool(of id: UUID) -> LiftPool? {
        entries.first { $0.exercises.contains { $0.id == id } }?.pool
    }

    func seeded(_ key: String) -> LibraryExercise? {
        for e in entries {
            if let hit = e.exercises.first(where: { $0.seedKey == key }) { return hit }
        }
        return nil
    }

    /// Resolve a slot's exercise: canonical UUID first, then legacy (pool, exIdx)
    /// seed reference. Custom-text slots resolve to nil by design.
    func resolve(_ slot: Slot) -> LibraryExercise? {
        guard slot.custom == nil else { return nil }
        if let id = slot.exerciseID, let hit = exercise(id: id) { return hit }
        if let idx = slot.exIdx { return seeded("\(slot.pool.rawValue):\(idx)") }
        return nil
    }

    // MARK: editing

    mutating func add(_ ex: LibraryExercise, to pool: LiftPool) {
        self[pool] = self[pool] + [ex]
    }

    mutating func update(_ ex: LibraryExercise) {
        for i in entries.indices {
            if let j = entries[i].exercises.firstIndex(where: { $0.id == ex.id }) {
                entries[i].exercises[j] = ex
                return
            }
        }
    }

    mutating func setArchived(_ id: UUID, _ flag: Bool) {
        for i in entries.indices {
            if let j = entries[i].exercises.firstIndex(where: { $0.id == id }) {
                entries[i].exercises[j].archived = flag
                return
            }
        }
    }

    /// Hard delete — only for coach-added entries; built-ins archive instead.
    mutating func remove(_ id: UUID) {
        for i in entries.indices {
            entries[i].exercises.removeAll { $0.id == id && $0.seedKey == nil }
        }
    }
}
