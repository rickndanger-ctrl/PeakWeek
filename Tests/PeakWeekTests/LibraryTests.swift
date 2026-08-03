import XCTest
@testable import PeakWeek

final class LibraryTests: XCTestCase {

    let maxes = Maxes(squat: 405, bench: 275, deadlift: 495)

    // MARK: - seeding

    func testSeededLibraryMatchesCatalogueExactly() {
        let lib = ExerciseLibrary.seeded()
        for pool in LiftPool.allCases {
            let seeds = Engine.pools[pool] ?? []
            let entries = lib[pool]
            XCTAssertEqual(entries.count, seeds.count, "\(pool) count")
            for (i, seed) in seeds.enumerated() {
                XCTAssertEqual(entries[i].name, seed.name)
                XCTAssertEqual(entries[i].mod, seed.mod)
                XCTAssertEqual(entries[i].seedKey, "\(pool.rawValue):\(i)")
                XCTAssertFalse(entries[i].archived)
            }
        }
    }

    // MARK: - generation resolves IDs

    func testGeneratedProgramCarriesExerciseIDs() {
        let lib = ExerciseLibrary.seeded()
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        for week in p.weeks {
            for day in week.days {
                for slot in day.slots {
                    XCTAssertNotNil(slot.exerciseID,
                                    "wk\(week.num) \(day.title): every generated slot resolves to a library ID")
                    XCTAssertNotNil(lib.exercise(id: slot.exerciseID!))
                }
            }
        }
    }

    func testGeneratedOutputIdenticalToLegacy() {
        // Golden: with a seeded library, names/loads are byte-identical to the
        // pre-library engine output.
        let lib = ExerciseLibrary.seeded()
        let client = Client(name: "Test", unit: .lb, maxes: maxes)
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let text = Engine.weekToText(client: client, program: p, week: p.weeks[0], library: lib)
        XCTAssertTrue(text.contains("Competition Squat — 4x6 @ 67% → 270 lb · RPE 7"))
        XCTAssertTrue(text.contains("Larsen Press — 4x8 @ 58% → 145 lb · RPE 7"))
    }

    // MARK: - customization safety

    func testRenameDoesNotCorruptSavedPrograms() {
        var lib = ExerciseLibrary.seeded()
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let squatSlot = p.weeks[0].days[0].slots[0]
        var comp = lib[.squat][0]
        comp.name = "Comp Squat (walked out)"
        lib.update(comp)
        XCTAssertEqual(Engine.slotName(squatSlot, library: lib), "Comp Squat (walked out)",
                       "rename follows the UUID — no index corruption")
        XCTAssertEqual(Engine.slotLoad(squatSlot, maxes: maxes, unit: .lb, library: lib), 270,
                       "load unchanged by rename")
    }

    func testModEditRecalculatesLoads() {
        var lib = ExerciseLibrary.seeded()
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let pauseSlot = p.weeks[0].days[0].slots[1]      // Pause Squat 3x6 @60%, mod 0.9 -> 220
        var pause = lib[.squat][1]
        pause.mod = 0.85
        lib.update(pause)
        // 405 * 0.60 * 0.85 = 206.55 -> 205
        XCTAssertEqual(Engine.slotLoad(pauseSlot, maxes: maxes, unit: .lb, library: lib), 205)
    }

    func testExclusionSubstitutesWithinPool() {
        let lib = ExerciseLibrary.seeded()
        let legPress = lib[.quads][0]                     // acc Day 1 uses quads index 0
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false,
                                    library: lib, excluded: [legPress.id])
        let day1 = p.weeks[0].days[0]
        let quadSlot = day1.slots.first { $0.pool == .quads }!
        XCTAssertNotEqual(quadSlot.exerciseID, legPress.id, "excluded exercise is substituted")
        let sub = lib.exercise(id: quadSlot.exerciseID!)!
        XCTAssertEqual(sub.name, "Hack Squat", "substitute is the next exercise in the same pool")
    }

    func testArchivedExerciseStillResolvesInOldPrograms() {
        var lib = ExerciseLibrary.seeded()
        let p = Engine.buildProgram(startPhase: .full, totalWeeks: 12, fiveDay: false, library: lib)
        let squatSlot = p.weeks[0].days[0].slots[0]
        lib.setArchived(squatSlot.exerciseID!, true)
        XCTAssertEqual(Engine.slotName(squatSlot, library: lib), "Competition Squat",
                       "archived exercises keep resolving in saved programs")
    }

    func testCoachAddedExerciseComputesLoad() {
        var lib = ExerciseLibrary.seeded()
        let ssb = LibraryExercise(name: "SSB Squat vs Chains", mod: 0.8)
        lib.add(ssb, to: .squat)
        let slot = Slot(pool: .squat, exerciseID: ssb.id, sets: 3, reps: 5, pct: 70, rpe: 8)
        // 405 * 0.7 * 0.8 = 226.8 -> 225
        XCTAssertEqual(Engine.slotLoad(slot, maxes: maxes, unit: .lb, library: lib), 225)
        XCTAssertEqual(Engine.slotName(slot, library: lib), "SSB Squat vs Chains")
    }

    func testHardDeleteOnlyRemovesCoachAdded() {
        var lib = ExerciseLibrary.seeded()
        let custom = LibraryExercise(name: "Belt Squat", mod: nil)
        lib.add(custom, to: .quads)
        lib.remove(custom.id)
        XCTAssertNil(lib.exercise(id: custom.id))
        let builtin = lib[.squat][0]
        lib.remove(builtin.id)
        XCTAssertNotNil(lib.exercise(id: builtin.id), "built-ins cannot be hard-deleted")
    }

    // MARK: - custom exercises auto-save into the library

    func testResolveOrCreateAddsNewExercise() {
        var lib = ExerciseLibrary.seeded()
        let ex = lib.resolveOrCreate(named: "  Belt Squat March ", in: .quads)
        XCTAssertEqual(ex?.name, "Belt Squat March", "trimmed before saving")
        XCTAssertNil(ex?.mod, "auto-saved entries are accessories (RPE-only)")
        XCTAssertNil(ex?.seedKey, "coach-added, not built-in")
        XCTAssertTrue(lib[.quads].contains { $0.id == ex?.id })
    }

    func testResolveOrCreateDeduplicatesByName() {
        var lib = ExerciseLibrary.seeded()
        let first = lib.resolveOrCreate(named: "Belt Squat", in: .quads)
        let countAfterFirst = lib[.quads].count
        let second = lib.resolveOrCreate(named: "belt squat", in: .hams)   // different case AND pool
        XCTAssertEqual(first?.id, second?.id, "case-insensitive reuse across pools")
        XCTAssertEqual(lib[.quads].count, countAfterFirst, "no duplicate created")
        // Built-ins dedup too:
        let comp = lib.resolveOrCreate(named: "competition squat", in: .quads)
        XCTAssertEqual(comp?.seedKey, "squat:0", "matches the built-in, not a copy")
    }

    func testResolveOrCreateRevivesArchived() {
        var lib = ExerciseLibrary.seeded()
        let ex = lib.resolveOrCreate(named: "Reverse Hyper", in: .hams)!
        lib.setArchived(ex.id, true)
        let again = lib.resolveOrCreate(named: "Reverse Hyper", in: .hams)
        XCTAssertEqual(again?.id, ex.id)
        XCTAssertEqual(again?.archived, false, "explicitly reused entries unarchive")
    }

    func testResolveOrCreateRejectsEmpty() {
        var lib = ExerciseLibrary.seeded()
        XCTAssertNil(lib.resolveOrCreate(named: "   ", in: .quads))
    }

    // MARK: - migration: legacy exIdx slots gain IDs on decode

    func testLegacySlotsMigrateToExerciseIDs() throws {
        // Simulate a pre-library file: program slots carry pool+exIdx only.
        var lib = ExerciseLibrary.seeded()
        var client = Client(name: "Old", unit: .lb, maxes: maxes)
        var program = Engine.buildProgramLegacy(startPhase: .full, totalWeeks: 12, fiveDay: false)
        XCTAssertNil(program.weeks[0].days[0].slots[0].exerciseID, "legacy builder leaves IDs nil")
        client.program = program
        var appData = AppData(clients: [client])
        appData.exerciseLibrary = lib

        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(AppData.self, from: enc.encode(appData))

        lib = decoded.exerciseLibrary
        for week in decoded.clients[0].program!.weeks {
            for day in week.days {
                for slot in day.slots where slot.custom == nil {
                    XCTAssertNotNil(slot.exerciseID, "migration fills every slot ID")
                    XCTAssertNotNil(lib.exercise(id: slot.exerciseID!))
                }
            }
        }
        // Canonical numbers survive the migration.
        let w1s = decoded.clients[0].program!.weeks[0].days[0].slots[0]
        XCTAssertEqual(Engine.slotName(w1s, library: lib), "Competition Squat")
        XCTAssertEqual(Engine.slotLoad(w1s, maxes: maxes, unit: .lb, library: lib), 270)
    }
}
