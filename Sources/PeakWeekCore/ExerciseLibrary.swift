import Foundation

// MARK: - Editable exercise library
// Source of truth for exercises. Seeded from Engine's catalogue on first run;
// coaches add/rename/archive entries and edit load modifiers. Slots reference
// exercises by stable UUID so edits never corrupt saved programs.

public struct LibraryExercise: Codable, Identifiable, Hashable {
    public var id: UUID = UUID()
    public var seedKey: String?      // "squat:0" … for built-ins; nil for coach-added
    public var name: String
    public var mod: Double?          // load modifier vs comp 1RM; nil = accessory (RPE-only)
    public var archived: Bool = false

    public init(id: UUID = UUID(), seedKey: String? = nil, name: String,
         mod: Double? = nil, archived: Bool = false) {
        self.id = id; self.seedKey = seedKey; self.name = name
        self.mod = mod; self.archived = archived
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        seedKey = try c.decodeIfPresent(String.self, forKey: .seedKey)
        name = try c.decode(String.self, forKey: .name)
        mod = try c.decodeIfPresent(Double.self, forKey: .mod)
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
    }
}

public struct PoolEntries: Codable, Hashable, Identifiable {
    public var pool: LiftPool
    public var exercises: [LibraryExercise]
    public var id: LiftPool { pool }
}

public struct ExerciseLibrary: Codable, Hashable {
    public var entries: [PoolEntries]

    public init(entries: [PoolEntries]) {
        self.entries = entries
    }

    /// Built from the engine's seed catalogue, preserving exact order so
    /// (pool, index) references map 1:1 onto seeded UUIDs.
    public static func seeded() -> ExerciseLibrary {
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

    public subscript(pool: LiftPool) -> [LibraryExercise] {
        get { entries.first { $0.pool == pool }?.exercises ?? [] }
        set {
            if let i = entries.firstIndex(where: { $0.pool == pool }) {
                entries[i].exercises = newValue
            } else {
                entries.append(PoolEntries(pool: pool, exercises: newValue))
            }
        }
    }

    public func exercise(id: UUID) -> LibraryExercise? {
        for e in entries {
            if let hit = e.exercises.first(where: { $0.id == id }) { return hit }
        }
        return nil
    }

    public func pool(of id: UUID) -> LiftPool? {
        entries.first { $0.exercises.contains { $0.id == id } }?.pool
    }

    public func seeded(_ key: String) -> LibraryExercise? {
        for e in entries {
            if let hit = e.exercises.first(where: { $0.seedKey == key }) { return hit }
        }
        return nil
    }

    /// Resolve a slot's exercise: canonical UUID first, then legacy (pool, exIdx)
    /// seed reference. Custom-text slots resolve to nil by design.
    public func resolve(_ slot: Slot) -> LibraryExercise? {
        guard slot.custom == nil else { return nil }
        if let id = slot.exerciseID, let hit = exercise(id: id) { return hit }
        if let idx = slot.exIdx { return seeded("\(slot.pool.rawValue):\(idx)") }
        return nil
    }

    /// Library upgrade: seed exercises added in newer app versions are merged
    /// into existing libraries (append-only, keyed by seedKey — coach edits,
    /// custom entries, and ordering are untouched).
    public mutating func mergeNewSeeds() {
        for pool in LiftPool.allCases {
            let seeds = Engine.pools[pool] ?? []
            for (i, seed) in seeds.enumerated() {
                let key = "\(pool.rawValue):\(i)"
                if seeded(key) == nil {
                    add(LibraryExercise(seedKey: key, name: seed.name, mod: seed.mod), to: pool)
                }
            }
        }
    }

    /// Case-insensitive name lookup across all pools (unarchived preferred).
    public func findByName(_ name: String) -> LibraryExercise? {
        let needle = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return nil }
        var archivedHit: LibraryExercise?
        for e in entries {
            for ex in e.exercises where ex.name.lowercased() == needle {
                if ex.archived { archivedHit = archivedHit ?? ex } else { return ex }
            }
        }
        return archivedHit
    }

    /// The coach typed an exercise name into a slot: reuse the library entry
    /// if one exists (reviving it if archived), otherwise create it in `pool`
    /// as an accessory (RPE-only — set a load modifier in Settings for
    /// computed loads). Returns the canonical entry.
    public mutating func resolveOrCreate(named name: String, in pool: LiftPool) -> LibraryExercise? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let existing = findByName(trimmed) {
            if existing.archived { setArchived(existing.id, false) }
            return exercise(id: existing.id)
        }
        let ex = LibraryExercise(name: trimmed, mod: nil)
        add(ex, to: pool)
        return ex
    }

    // MARK: editing

    public mutating func add(_ ex: LibraryExercise, to pool: LiftPool) {
        self[pool] = self[pool] + [ex]
    }

    public mutating func update(_ ex: LibraryExercise) {
        for i in entries.indices {
            if let j = entries[i].exercises.firstIndex(where: { $0.id == ex.id }) {
                entries[i].exercises[j] = ex
                return
            }
        }
    }

    public mutating func setArchived(_ id: UUID, _ flag: Bool) {
        for i in entries.indices {
            if let j = entries[i].exercises.firstIndex(where: { $0.id == id }) {
                entries[i].exercises[j].archived = flag
                return
            }
        }
    }

    /// Hard delete — only for coach-added entries; built-ins archive instead.
    public mutating func remove(_ id: UUID) {
        for i in entries.indices {
            entries[i].exercises.removeAll { $0.id == id && $0.seedKey == nil }
        }
    }
}
