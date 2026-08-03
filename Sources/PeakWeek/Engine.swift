import Foundation

// MARK: - Engine: pools, RPE table, program builder.
// Direct port of the browser engine that passed the full test suite.

enum Engine {

    static let pools: [LiftPool: [Exercise]] = [
        .squat: [
            Exercise(name: "Competition Squat", mod: 1.0),
            Exercise(name: "Pause Squat", mod: 0.9),
            Exercise(name: "High-Bar Squat", mod: 0.92),
            Exercise(name: "Safety Bar Squat", mod: 0.87),
            Exercise(name: "Front Squat", mod: 0.82),
            Exercise(name: "Tempo Squat (3-0-0)", mod: 0.85),
            Exercise(name: "Pin Squat", mod: 0.88),
            Exercise(name: "Box Squat", mod: 0.92),
        ],
        .bench: [
            Exercise(name: "Competition Bench", mod: 1.0),
            Exercise(name: "Close-Grip Bench", mod: 0.92),
            Exercise(name: "Spoto Press", mod: 0.93),
            Exercise(name: "Larsen Press", mod: 0.9),
            Exercise(name: "Tempo Bench (3-1-0)", mod: 0.9),
            Exercise(name: "Incline Bench", mod: 0.85),
            Exercise(name: "2-Board Press", mod: 1.02),
            Exercise(name: "Feet-Up Bench", mod: 0.92),
            // Conjugate-inspired additions (append-only: seed indices are stable)
            Exercise(name: "Floor Press", mod: 0.92),
            Exercise(name: "Low Pin Press", mod: 0.94),
            Exercise(name: "High Pin Press", mod: 1.05),
        ],
        .deadlift: [
            Exercise(name: "Competition Deadlift", mod: 1.0),
            Exercise(name: "Paused Deadlift", mod: 0.88),
            Exercise(name: "Deficit Deadlift", mod: 0.9),
            Exercise(name: "Block Pull", mod: 1.05),
            Exercise(name: "Romanian Deadlift", mod: 0.75),
            Exercise(name: "Snatch-Grip Deadlift", mod: 0.8),
            Exercise(name: "Stiff-Leg Deadlift", mod: 0.8),
            Exercise(name: "Opposite-Stance Deadlift", mod: 0.85),
            // Conjugate-inspired addition (append-only)
            Exercise(name: "Halting Deadlift", mod: 0.88),
        ],
        .quads: [
            Exercise(name: "Leg Press", mod: nil),
            Exercise(name: "Hack Squat", mod: nil),
            Exercise(name: "Walking Lunge", mod: nil),
            Exercise(name: "Bulgarian Split Squat", mod: nil),
            Exercise(name: "Leg Extension", mod: nil),
        ],
        .hams: [
            Exercise(name: "Lying Leg Curl", mod: nil),
            Exercise(name: "Glute-Ham Raise", mod: nil),
            Exercise(name: "Back Extension", mod: nil),
            Exercise(name: "Hip Thrust", mod: nil),
            Exercise(name: "Good Morning", mod: nil),
        ],
        .back: [
            Exercise(name: "Barbell Row", mod: nil),
            Exercise(name: "Chest-Supported Row", mod: nil),
            Exercise(name: "Lat Pulldown", mod: nil),
            Exercise(name: "Pull-Up", mod: nil),
            Exercise(name: "Seated Cable Row", mod: nil),
        ],
        .press: [
            Exercise(name: "Overhead Press", mod: nil),
            Exercise(name: "DB Shoulder Press", mod: nil),
            Exercise(name: "Dip", mod: nil),
            Exercise(name: "JM Press", mod: nil),
            Exercise(name: "Tricep Pushdown", mod: nil),
            Exercise(name: "Skull Crusher", mod: nil),
        ],
        // Coach's additions (2026-08-03): bracing + elbow insurance.
        .core: [
            Exercise(name: "Ab Wheel Rollout", mod: nil),
            Exercise(name: "Hanging Leg Raise", mod: nil),
            Exercise(name: "Cable Crunch", mod: nil),
            Exercise(name: "Plank (seconds)", mod: nil),
        ],
        .arms: [
            Exercise(name: "DB Curl", mod: nil),
            Exercise(name: "EZ-Bar Curl", mod: nil),
            Exercise(name: "Hammer Curl", mod: nil),
        ],
    ]

    /// RTS / Tuchscherer style: reps -> (RPE -> % of 1RM)
    static let rpeTable: [(reps: Int, row: [(rpe: Double, pct: Int)])] = [
        (1,  [(7, 89), (7.5, 91), (8, 92), (8.5, 94), (9, 96), (9.5, 98), (10, 100)]),
        (2,  [(7, 86), (7.5, 88), (8, 89), (8.5, 91), (9, 92), (9.5, 94), (10, 96)]),
        (3,  [(7, 84), (7.5, 85), (8, 86), (8.5, 88), (9, 89), (9.5, 91), (10, 92)]),
        (4,  [(7, 81), (7.5, 82), (8, 84), (8.5, 85), (9, 86), (9.5, 88), (10, 89)]),
        (5,  [(7, 79), (7.5, 80), (8, 81), (8.5, 82), (9, 84), (9.5, 85), (10, 86)]),
        (6,  [(7, 76), (7.5, 77), (8, 79), (8.5, 80), (9, 81), (9.5, 82), (10, 84)]),
        (8,  [(7, 71), (7.5, 72), (8, 74), (8.5, 75), (9, 76), (9.5, 77), (10, 79)]),
        (10, [(7, 65), (7.5, 67), (8, 68), (8.5, 70), (9, 71), (9.5, 72), (10, 74)]),
    ]

    // MARK: helpers

    static func roundLoad(_ x: Double, unit: Unit) -> Double {
        let step = unit.step
        return max(step, (x / step).rounded() * step)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// e1RM from a top set (load × reps @ RPE) via the RTS table, interpolating
    /// between listed rep rows (7 ⇒ between 6 and 8) and half-RPE columns.
    /// This is the coach's reference max convention: program off the LAST
    /// BLOCK'S e1RM, not a months-old gym single.
    static func e1RM(load: Double, reps: Int, rpe: Double) -> Double? {
        guard load > 0, reps >= 1, reps <= 12, rpe >= 6.5, rpe <= 10 else { return nil }
        let clampedRPE = min(10, max(7, rpe))   // table floor is 7; 6.5 rounds up

        func pct(forReps r: Int) -> Double? {
            guard let row = rpeTable.first(where: { $0.reps == r })?.row else { return nil }
            // Exact column or linear interpolation between half-steps.
            if let hit = row.first(where: { $0.rpe == clampedRPE }) { return Double(hit.pct) }
            guard let lower = row.last(where: { $0.rpe < clampedRPE }),
                  let upper = row.first(where: { $0.rpe > clampedRPE }) else { return nil }
            let t = (clampedRPE - lower.rpe) / (upper.rpe - lower.rpe)
            return lerp(Double(lower.pct), Double(upper.pct), t)
        }

        let listed = rpeTable.map(\.reps)
        let percent: Double?
        if listed.contains(reps) {
            percent = pct(forReps: reps)
        } else if reps < (listed.max() ?? 10) {
            // Interpolate between neighbouring rep rows (7 → 6 & 8, 9 → 8 & 10).
            guard let below = listed.last(where: { $0 < reps }),
                  let above = listed.first(where: { $0 > reps }),
                  let pLow = pct(forReps: below), let pHigh = pct(forReps: above) else { return nil }
            let t = Double(reps - below) / Double(above - below)
            percent = lerp(pLow, pHigh, t)
        } else {
            // Beyond the table (11-12 reps): extend the 8→10 slope conservatively.
            guard let p8 = pct(forReps: 8), let p10 = pct(forReps: 10) else { return nil }
            percent = p10 + (p10 - p8) / 2 * Double(reps - 10)
        }
        guard let percent, percent > 0 else { return nil }
        return load / (percent / 100)
    }

    static func loadString(_ x: Double, unit: Unit) -> String {
        let v = x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
        return "\(v) \(unit.rawValue)"
    }

    // MARK: block allocation

    static func allocateBlocks(_ n: Int) -> [Block] {
        let real = min(4, max(3, Int((Double(n) * 0.24).rounded())))
        let hasDeload = n >= 12
        let remaining = n - real - (hasDeload ? 1 : 0)
        let acc = Int((Double(remaining) / 2).rounded())
        let trans = remaining - acc
        var blocks = [Block(phase: .acc, weeks: acc)]
        if hasDeload { blocks.append(Block(phase: .deload, weeks: 1)) }
        blocks.append(Block(phase: .trans, weeks: trans))
        blocks.append(Block(phase: .real, weeks: real))
        return blocks
    }

    static func allocateOffSeason(_ n: Int) -> [Block] {
        let hyp = Int((Double(n - 1) / 2).rounded())
        return [
            Block(phase: .acc, weeks: hyp),
            Block(phase: .deload, weeks: 1),
            Block(phase: .trans, weeks: n - 1 - hyp),
        ]
    }

    // MARK: day templates

    private static func slot(_ pool: LiftPool, _ exIdx: Int, _ sets: Int, _ reps: Int,
                             _ pct: Double?, _ rpe: Double) -> Slot {
        Slot(pool: pool, exIdx: exIdx, sets: sets, reps: reps,
             pct: pct.map { $0.rounded() }, rpe: rpe)
    }

    static func dayTemplates(phase: Phase, t: Double, weeksOut: Int?, fiveDay: Bool) -> [DayPlan] {
        let S = slot
        switch phase {
        case .acc:
            var days = [
                DayPlan(title: "Day 1 — Squat", slots: [
                    S(.squat, 0, 4, 6, lerp(67, 75, t), 7),
                    S(.squat, 1, 3, 6, lerp(60, 66, t), 7),
                    S(.quads, 0, 3, 10, nil, 8),
                    S(.hams, 0, 3, 10, nil, 8),
                    S(.core, 0, 3, 10, nil, 8),      // coach: bracing work on squat days
                ]),
                DayPlan(title: "Day 2 — Bench", slots: [
                    S(.bench, 0, 4, 8, lerp(65, 72, t), 7),
                    S(.bench, 1, 3, 8, lerp(60, 65, t), 7.5),
                    S(.press, 0, 3, 10, nil, 8),
                    S(.back, 2, 3, 12, nil, 8),
                ]),
                DayPlan(title: "Day 3 — Deadlift", slots: [
                    S(.deadlift, 0, 4, 6, lerp(67, 74, t), 7),
                    S(.deadlift, 4, 3, 8, lerp(55, 60, t), 7.5),
                    S(.back, 0, 4, 10, nil, 8),      // audit: back to 10 weekly direct sets
                    S(.hams, 3, 3, 10, nil, 8),
                ]),
                DayPlan(title: "Day 4 — Bench 2", slots: [
                    S(.bench, 3, 4, 8, lerp(58, 64, t), 7),
                    S(.back, 1, 3, 10, nil, 8),
                    S(.press, 4, 3, 12, nil, 8.5),
                    S(.quads, 4, 3, 12, nil, 8),
                ]),
            ]
            if fiveDay {
                days.append(DayPlan(title: "Day 5 — Squat 2 & Weak Points", slots: [
                    S(.squat, 2, 3, 8, lerp(58, 64, t), 7),
                    S(.back, 3, 3, 8, nil, 8),
                    S(.hams, 1, 3, 10, nil, 8),
                    S(.press, 5, 3, 12, nil, 8.5),
                ]))
            }
            return days

        case .trans:
            var days = [
                DayPlan(title: "Day 1 — Squat", slots: [
                    S(.squat, 0, 4, 4, lerp(77, 86, t), 7.5),
                    S(.squat, 1, 2, 3, lerp(70, 76, t), 7.5),
                    S(.hams, 0, 3, 8, nil, 8),
                    S(.core, 0, 2, 10, nil, 8),      // coach: bracing, tapered for the phase
                ]),
                DayPlan(title: "Day 2 — Bench", slots: [
                    S(.bench, 0, 4, 4, lerp(76, 85, t), 7.5),
                    S(.bench, 2, 3, 4, lerp(70, 76, t), 7.5),
                    S(.back, 4, 3, 10, nil, 8),
                ]),
                DayPlan(title: "Day 3 — Deadlift", slots: [
                    S(.deadlift, 0, 4, 3, lerp(78, 87, t), 8),
                    S(.deadlift, 3, 2, 3, lerp(72, 78, t), 7.5),
                    S(.back, 1, 3, 8, nil, 8),
                ]),
                DayPlan(title: "Day 4 — Bench 2", slots: [
                    S(.bench, 1, 4, 5, lerp(70, 76, t), 7.5),
                    S(.press, 3, 3, 8, nil, 8),
                    S(.back, 3, 3, 8, nil, 8),
                ]),
            ]
            if fiveDay {
                days.append(DayPlan(title: "Day 5 — Squat 2", slots: [
                    S(.squat, 1, 3, 5, lerp(68, 74, t), 7.5),
                    S(.back, 0, 3, 8, nil, 8),
                    S(.hams, 4, 3, 8, nil, 8),
                ]))
            }
            return days

        case .deload:
            return [
                DayPlan(title: "Day 1 — Squat", slots: [
                    S(.squat, 0, 3, 5, 62, 6), S(.quads, 0, 2, 10, nil, 6),
                ]),
                DayPlan(title: "Day 2 — Bench", slots: [
                    S(.bench, 0, 3, 5, 62, 6), S(.back, 2, 2, 10, nil, 6),
                ]),
                DayPlan(title: "Day 3 — Deadlift", slots: [
                    S(.deadlift, 0, 2, 4, 62, 6), S(.hams, 2, 2, 10, nil, 6),
                ]),
                DayPlan(title: "Day 4 — Optional", slots: [
                    S(.press, 1, 2, 10, nil, 6), S(.back, 4, 2, 10, nil, 6),
                ]),
            ]

        case .real:
            let out = weeksOut ?? 3
            if out >= 3 {
                return [
                    DayPlan(title: "Day 1 — Squat", slots: [
                        S(.squat, 0, 3, 3, 87, 8), S(.squat, 1, 2, 2, 78, 7.5), S(.hams, 0, 2, 8, nil, 7.5),
                    ]),
                    DayPlan(title: "Day 2 — Bench", slots: [
                        S(.bench, 0, 3, 3, 86, 8), S(.bench, 2, 2, 3, 78, 7.5), S(.back, 4, 3, 8, nil, 7.5),
                    ]),
                    DayPlan(title: "Day 3 — Deadlift", slots: [
                        S(.deadlift, 0, 3, 2, 88, 8), S(.back, 1, 3, 8, nil, 7.5),
                    ]),
                    DayPlan(title: "Day 4 — Bench 2", slots: [
                        S(.bench, 0, 3, 4, 78, 7.5), S(.press, 4, 2, 10, nil, 7.5),
                    ]),
                ]
            }
            if out == 2 {
                return [
                    DayPlan(title: "Day 1 — Squat (heavy double)", slots: [
                        S(.squat, 0, 2, 2, 90, 8.5), S(.squat, 0, 2, 2, 82, 7.5), S(.hams, 0, 2, 8, nil, 7),
                    ]),
                    DayPlan(title: "Day 2 — Bench (heavy double)", slots: [
                        S(.bench, 0, 2, 2, 89, 8.5), S(.bench, 0, 2, 3, 80, 7.5), S(.back, 4, 2, 8, nil, 7),
                    ]),
                    DayPlan(title: "Day 3 — LAST HEAVY DEADLIFT (10–14 days out)", slots: [
                        S(.deadlift, 0, 1, 1, 92, 8.5), S(.deadlift, 0, 2, 2, 84, 7.5),
                    ]),
                    DayPlan(title: "Day 4 — Bench technique", slots: [
                        S(.bench, 0, 3, 3, 75, 7), S(.back, 2, 2, 10, nil, 7),
                    ]),
                ]
            }
            return [
                DayPlan(title: "Day 1 — Squat OPENER (single @ ~92%)", slots: [
                    S(.squat, 0, 1, 1, 92, 8), S(.squat, 0, 2, 2, 80, 7),
                ]),
                DayPlan(title: "Day 2 — Bench OPENER (single @ ~92%)", slots: [
                    S(.bench, 0, 1, 1, 92, 8), S(.bench, 0, 2, 2, 80, 7),
                ]),
                DayPlan(title: "Day 3 — Deadlift speed work", slots: [
                    S(.deadlift, 0, 3, 1, 78, 6.5),
                ]),
                DayPlan(title: "Day 4 — Light bench touch-up", slots: [
                    S(.bench, 0, 2, 3, 70, 6),
                ]),
            ]

        case .meet:
            return [
                DayPlan(title: "Mon/Tue — Technique primer", slots: [
                    S(.squat, 0, 2, 2, 60, 5), S(.bench, 0, 2, 2, 60, 5), S(.deadlift, 0, 1, 2, 55, 5),
                ]),
                DayPlan(title: "Wed–Fri — Rest, hydrate, sleep", slots: []),
            ]

        case .hyp:
            // Hypertrophy weeks are built by buildHypertrophy via hypDays
            // (the meso spine carries reps/%); this fallback covers only a
            // structurally-edited stray and mirrors an early meso week.
            return hypDays(reps: 10, pct: 65, weekInMeso: 1, fiveDay: fiveDay)
        }
    }

    // MARK: - Opt-in schemes (never applied automatically)

    /// WAVE transmutation: 3-week mini-cycles — reps fall, weight rises, then
    /// the bar drops back and the next wave starts 2.5% heavier. The block
    /// always ENDS on the full top wave, so realization chains unchanged.
    /// (Final-wave pins: SQ 79/82.5/86 · BP 78/81.5/85 · DL 80/83.5/87.)
    static func waveOverride(week: Int, blockLen: Int, lift: LiftPool)
        -> (sets: Int, reps: Int, pct: Double, rpe: Double)? {
        guard blockLen >= 1, week >= 1, week <= blockLen else { return nil }
        let pins: [LiftPool: [Double]] = [
            .squat: [79, 82.5, 86], .bench: [78, 81.5, 85], .deadlift: [80, 83.5, 87],
        ]
        let repScheme: [LiftPool: [Int]] = [
            .squat: [5, 4, 3], .bench: [5, 4, 3], .deadlift: [4, 3, 2],
        ]
        guard let pin = pins[lift], let reps = repScheme[lift] else { return nil }
        let waves = (blockLen + 2) / 3                 // ceil(N/3)
        let skip = 3 * waves - blockLen                // steps dropped from wave 1's front
        let g = week + skip                            // global step index
        let wave = (g + 2) / 3
        let step = ((g - 1) % 3)                       // 0..2
        let pct = pin[step] - 2.5 * Double(waves - wave)
        let rpe: Double = lift == .deadlift ? 8.0 : [7.0, 7.5, 8.0][step]
        return (4, reps[step], pct, rpe)
    }

    /// DUP accumulation: each lift sees different jobs across the week —
    /// volume (H), speed (P), strength (S) — with %-bands that progress by the
    /// same lerp discipline as the factory templates.
    static func dupAccDays(week w: Int, blockLen N: Int, fiveDay: Bool) -> [DayPlan] {
        let S = slot
        func band(_ lo: Double, _ hi: Double) -> Double {
            N > 1 ? lerp(lo, hi, Double(w - 1) / Double(N - 1)) : lo
        }
        /// Day-1 alternation evaluates the lerp on its own parity sequence.
        func parityBand(_ lo: Double, _ hi: Double) -> Double {
            let mine = stride(from: (w % 2 == 1) ? 1 : 2, through: N, by: 2).map { $0 }
            guard let i = mine.firstIndex(of: w), mine.count > 1 else { return lo }
            return lerp(lo, hi, Double(i) / Double(mine.count - 1))
        }
        func speed(_ s: Slot) -> Slot { var s = s; s.note = "max bar speed"; return s }

        var day1: DayPlan
        if fiveDay {
            day1 = DayPlan(title: "Day 1 — Squat (volume)", slots: [
                S(.squat, 0, 4, 8, band(65, 71), 7),
                speed(S(.squat, 1, 3, 3, band(68, 72), 6.5)),
                S(.quads, 0, 3, 10, nil, 8),
                S(.hams, 0, 3, 10, nil, 8),
                S(.core, 0, 3, 10, nil, 8),          // coach: bracing work on squat days
            ])
        } else {
            let odd = w % 2 == 1
            day1 = DayPlan(title: odd ? "Day 1 — Squat (volume)" : "Day 1 — Squat (strength)", slots: [
                odd ? S(.squat, 0, 4, 8, parityBand(65, 71), 7)
                    : S(.squat, 0, 4, 5, parityBand(75, 81), 7.5),
                speed(S(.squat, 1, 4, 3, band(68, 72), 6.5)),
                S(.quads, 0, 3, 10, nil, 8),
                S(.hams, 0, 3, 10, nil, 8),
                S(.core, 0, 3, 10, nil, 8),          // coach: bracing work on squat days
            ])
        }
        var days = [
            day1,
            DayPlan(title: "Day 2 — Bench (volume)", slots: [
                S(.bench, 0, 4, 8, band(65, 71), 7),
                S(.bench, 2, 3, 8, band(60, 65), 7.5),
                S(.press, 0, 3, 10, nil, 8),
                S(.back, 2, 3, 12, nil, 8),
            ]),
            DayPlan(title: "Day 3 — Deadlift (strength)", slots: [
                S(.deadlift, 0, 4, 4, band(76, 82), 7.5),
                S(.deadlift, 4, 3, 8, band(55, 60), 7.5),
                S(.back, 0, 4, 10, nil, 8),          // audit: back to 10 weekly direct sets
                S(.hams, 1, 3, 10, nil, 8),
            ]),
            DayPlan(title: "Day 4 — Bench (speed + strength)", slots: [
                speed(S(.bench, 1, 4, 3, band(68, 72), 6.5)),
                S(.bench, 0, 4, 5, band(75, 81), 7.5),
                S(.back, 1, 3, 10, nil, 8),
                S(.press, 4, 3, 12, nil, 8.5),
            ]),
        ]
        if fiveDay {
            // Audit fix: the 5th day must add PULL, not a third overhead press —
            // without it the DUP week ran 21 pressing : 9 pulling sets.
            days.append(DayPlan(title: "Day 5 — Squat (strength)", slots: [
                S(.squat, 0, 4, 5, band(75, 81), 7.5),
                S(.hams, 2, 3, 10, nil, 8),
                S(.hams, 3, 3, 10, nil, 8),
                S(.back, 3, 3, 8, nil, 8),          // Pull-Up (mirrors factory day 5)
            ]))
        }
        return days
    }

    // MARK: - Hypertrophy off-season

    enum HypWeek: Equatable {
        case work(reps: Int, pct: Double)
        case deload
    }

    /// Explicit meso spine per total length (auditable, pinned by tests):
    /// reps step 12 → 10 → 8 while %s climb; deloads separate mesos.
    static func hypSpine(totalWeeks: Int) -> [HypWeek] {
        func work(_ reps: Int, _ pcts: [Double]) -> [HypWeek] {
            pcts.map { .work(reps: reps, pct: $0) }
        }
        switch totalWeeks {
        case ...8:
            return work(12, [60, 61, 62, 63]) + [.deload] + work(10, [65, 67, 68])
        case 9:
            return work(12, [60, 61, 62, 63]) + [.deload] + work(10, [64, 65, 67, 68])
        case 10:
            return work(12, [60, 61, 62, 63]) + [.deload] + work(10, [64, 65, 67, 68]) + work(8, [70])
        case 11:
            return work(12, [60, 61, 62, 63]) + [.deload] + work(10, [64, 65, 67, 68]) + [.deload] + work(8, [71])
        default:
            return work(12, [60, 61, 62, 63]) + [.deload] + work(10, [64, 65, 67, 68]) + [.deload] + work(8, [70, 72])
        }
    }

    /// Day templates for one hypertrophy week. Main variation carries the
    /// spine's sets×reps@%; secondary = 3×8 @ main−2; the first two
    /// accessories/day ramp 3→4 sets in meso weeks 3+.
    static func hypDays(reps: Int, pct: Double, weekInMeso: Int, fiveDay: Bool) -> [DayPlan] {
        let S = slot
        let accSets = weekInMeso >= 3 ? 4 : 3
        var days = [
            DayPlan(title: "Day 1 — Squat (volume)", slots: [
                S(.squat, 2, 4, reps, pct, 8),          // High-Bar main
                S(.squat, 1, 3, 8, pct - 2, 7.5),       // Pause secondary
                S(.quads, 0, accSets, 12, nil, 8),
                S(.quads, 2, accSets, 12, nil, 8),
                S(.quads, 4, 3, 15, nil, 8.5),
                S(.hams, 0, 3, 12, nil, 8),
                S(.core, 0, 3, 12, nil, 8),          // coach: bracing work on squat days
            ]),
            DayPlan(title: "Day 2 — Bench (volume)", slots: [
                S(.bench, 1, 4, reps, pct, 8),          // Close-Grip main
                S(.bench, 5, 3, 8, pct - 2, 7.5),       // Incline secondary
                S(.press, 2, accSets, 10, nil, 8),
                S(.press, 1, accSets, 12, nil, 8),
                // Audit fix: the day's only pull (a compound) goes BEFORE the
                // isolation finisher, not dead last in a 19-21 set session.
                S(.back, 2, 3, 12, nil, 8),
                S(.press, 4, 3, 15, nil, 8.5),
            ]),
            DayPlan(title: "Day 3 — Hinge (volume)", slots: [
                S(.deadlift, 4, 4, reps, pct, 8),       // RDL main
                S(.deadlift, 5, 3, 8, pct - 2, 7.5),    // Snatch-Grip secondary
                S(.back, 0, accSets, 10, nil, 8),
                S(.hams, 1, accSets, 10, nil, 8),
                S(.back, 4, 3, 12, nil, 8),
                S(.hams, 2, 3, 12, nil, 8),
                S(.arms, 0, 3, 12, nil, 8),          // coach: a little bicep work, off-season
            ]),
            DayPlan(title: "Day 4 — Bench 2 (volume)", slots: [
                S(.bench, 3, 4, reps, pct, 8),          // Larsen main
                S(.bench, 7, 3, 8, pct - 2, 7.5),       // Feet-Up secondary
                S(.back, 3, accSets, 8, nil, 8),
                S(.back, 1, 3, 12, nil, 8),
                S(.press, 0, 3, 10, nil, 7.5),
                S(.press, 5, 3, 12, nil, 8),
            ]),
        ]
        if fiveDay {
            days.append(DayPlan(title: "Day 5 — Squat 2 (volume)", slots: [
                S(.squat, 3, 4, reps, pct, 8),          // SSB main
                S(.squat, 7, 3, 8, pct - 2, 7.5),       // Box secondary
                S(.quads, 3, accSets, 10, nil, 8),
                S(.hams, 3, 3, 10, nil, 8),
                S(.hams, 4, 3, 10, nil, 7.5),
                S(.arms, 0, 3, 12, nil, 8),          // audit+coach: curls replace 3rd triceps slot
                S(.core, 1, 3, 12, nil, 8),          // coach: bracing on the second squat day
            ]))
        }
        return days
    }

    // MARK: meet-date planning

    /// Full training weeks available when week 1 starts on `startMonday` and
    /// the meet falls on `meetDate` (the meet lands inside the final week).
    static func weeksAvailable(startMonday: Date, meetDate: Date,
                               calendar: Calendar = .current) -> Int {
        guard meetDate >= startMonday else { return 0 }
        let days = calendar.dateComponents([.day], from: startMonday, to: meetDate).day ?? 0
        // ceil(days/7): a meet exactly k×7 days out is the LAST day of week k,
        // not the first day of week k+1 (same-day case stays week 1).
        return days == 0 ? 1 : (days + 6) / 7
    }

    /// What kind of prep fits the runway. The coach's rule: pick up a lifter
    /// any distance out (minimum 3 weeks) and the app places them in the right
    /// phase for the time remaining.
    struct MeetPlan: Equatable {
        var phase: StartPhase
        var weeks: Int
        var blockPlan: BlockPlan?
        var summary: String
    }

    static func meetPlan(availableWeeks: Int) -> MeetPlan? {
        switch availableWeeks {
        case ..<3:
            return nil                              // too close to program — coach handles by hand
        case 3...4:
            return MeetPlan(phase: .real, weeks: availableWeeks, blockPlan: nil,
                            summary: "\(availableWeeks) wks out → peaking only (taper + meet week)")
        case 5...9:
            let real = availableWeeks >= 8 ? 4 : 3
            var plan = BlockPlan(acc: 0, deloadAfterAcc: false,
                                 trans: availableWeeks - real, real: real)
            plan.deloadAfterAcc = false
            return MeetPlan(phase: .full, weeks: availableWeeks, blockPlan: plan,
                            summary: "\(availableWeeks) wks out → strength \(plan.trans) wk + peaking \(real) wk (no time for a volume block)")
        case 10...16:
            return MeetPlan(phase: .full, weeks: availableWeeks, blockPlan: nil,
                            summary: "\(availableWeeks) wks out → full prep (volume / strength / peak)")
        default:
            // Extend the volume block to fill the runway (acc stepper caps at 10).
            let auto = allocateBlocks(16)
            var plan = BlockPlan()
            plan.acc = min(10, (auto.first { $0.phase == .acc }?.weeks ?? 6) + (availableWeeks - 16))
            plan.deloadAfterAcc = true
            plan.trans = auto.first { $0.phase == .trans }?.weeks ?? 5
            plan.real = auto.first { $0.phase == .real }?.weeks ?? 4
            let capped = plan.total < availableWeeks
            return MeetPlan(phase: .full, weeks: plan.total, blockPlan: plan,
                            summary: "\(availableWeeks) wks out → extended volume block (\(plan.acc) wk)"
                                + (capped ? " — caps at \(plan.total) wks; week 1 can start \(availableWeeks - plan.total) wk(s) later" : ""))
        }
    }

    // MARK: program builder

    /// Builds a program with slots resolved against the coach's exercise
    /// library. `excluded` exercises are substituted at generation time with
    /// the first available exercise from the same pool. A `blockPlan` overrides
    /// the automatic phase allocation for full preps.
    static func buildProgram(startPhase: StartPhase, totalWeeks: Int, fiveDay: Bool,
                             library: ExerciseLibrary, excluded: Set<UUID> = [],
                             blockPlan: BlockPlan? = nil) -> Program {
        var program = buildProgramLegacy(startPhase: startPhase, totalWeeks: totalWeeks,
                                         fiveDay: fiveDay, blockPlan: blockPlan)
        for wi in program.weeks.indices {
            resolveSlots(in: &program.weeks[wi], library: library, excluded: excluded)
        }
        return program
    }

    /// Resolve a week's template slots ((pool, exIdx) seed refs) to library
    /// UUIDs, substituting excluded/archived exercises within the same pool.
    static func resolveSlots(in week: inout Week, library: ExerciseLibrary,
                             excluded: Set<UUID>) {
        for di in week.days.indices {
            for si in week.days[di].slots.indices {
                var slot = week.days[di].slots[si]
                guard slot.custom == nil, slot.exerciseID == nil else { continue }
                guard let idx = slot.exIdx,
                      let seedHit = library.seeded("\(slot.pool.rawValue):\(idx)") else { continue }
                var chosen = seedHit
                if excluded.contains(chosen.id) || chosen.archived {
                    if let sub = library[slot.pool].first(where: {
                        !$0.archived && !excluded.contains($0.id)
                    }) { chosen = sub }
                }
                slot.exerciseID = chosen.id
                week.days[di].slots[si] = slot
            }
        }
    }

    /// A standalone deload week for insertion into an existing program.
    /// Numbering/grouping is fixed up by Program.renumberAndRegroup().
    static func makeDeloadWeek(fiveDay: Bool, library: ExerciseLibrary,
                               excluded: Set<UUID> = []) -> Week {
        var week = Week(num: 0, phase: .deload, weekInBlock: 1, blockLen: 1,
                        days: dayTemplates(phase: .deload, t: 0, weeksOut: nil, fiveDay: fiveDay))
        resolveSlots(in: &week, library: library, excluded: excluded)
        return week
    }

    /// The original index-referenced builder. Templates still speak (pool, index)
    /// against the seed catalogue; resolution to library UUIDs happens above.
    static func buildProgramLegacy(startPhase: StartPhase, totalWeeks: Int, fiveDay: Bool,
                                   blockPlan: BlockPlan? = nil) -> Program {
        let rawBlocks: [Block]
        switch startPhase {
        case .full:
            if let plan = blockPlan {
                var b: [Block] = []
                if plan.acc > 0 {
                    b.append(Block(phase: .acc, weeks: plan.acc))
                    if plan.deloadAfterAcc { b.append(Block(phase: .deload, weeks: 1)) }
                }
                b.append(Block(phase: .trans, weeks: max(1, plan.trans)))
                b.append(Block(phase: .real, weeks: max(2, plan.real)))
                rawBlocks = b
            } else {
                rawBlocks = allocateBlocks(totalWeeks)
            }
        case .offseason: rawBlocks = allocateOffSeason(totalWeeks)
        case .real: rawBlocks = [Block(phase: .real, weeks: min(4, max(3, totalWeeks)))]
        case .acc: rawBlocks = [Block(phase: .acc, weeks: totalWeeks)]
        case .trans: rawBlocks = [Block(phase: .trans, weeks: totalWeeks)]
        case .hypertrophy:
            // Dedicated builder: the meso spine drives everything.
            return buildHypertrophy(totalWeeks: totalWeeks, fiveDay: fiveDay)
        }

        let isMeetTrack = (startPhase == .full || startPhase == .real)
        var weeks: [Week] = []
        var w = 1

        for b in rawBlocks {
            for i in 0..<b.weeks {
                let isLast = (b.phase == .real && i == b.weeks - 1)
                let phase: Phase = (isLast && isMeetTrack) ? .meet : b.phase
                let t = b.weeks > 1 ? Double(i) / Double(b.weeks - 1) : 0
                let weeksOut: Int? = b.phase == .real ? (b.weeks - 1 - i) : nil
                var days = dayTemplates(phase: phase, t: t, weeksOut: weeksOut, fiveDay: fiveDay)
                // Opt-in schemes (coach's manual choice on the block plan):
                if phase == .acc, blockPlan?.accScheme == .dup {
                    days = dupAccDays(week: i + 1, blockLen: b.weeks, fiveDay: fiveDay)
                }
                if phase == .acc, let plan = blockPlan, plan.accScheme == .rpeAnchored {
                    // Trained-lifter entry point: comp-lift volume work anchored
                    // to honest RPEs (~6.5 entry → ~8.5 exit) instead of the
                    // soft factory ramp-in (6 @ 67% ≈ RPE 4). The band is
                    // COACH-ADJUSTABLE to match whatever program the lifter is
                    // transitioning from (defaults: 6s 72→80%). Bench eights
                    // derive rep-aware as entry−3 → top−5. RPE cap rises
                    // 7 → 8 across the block. Variation slots stay factory.
                    let lo = min(78, max(60, plan.accBandLo ?? 72))
                    let hi = min(84, max(lo + 2, plan.accBandHi ?? 80))
                    for di in 0...min(2, days.count - 1) {
                        guard let first = days[di].slots.first, first.exIdx == 0,
                              [LiftPool.squat, .bench, .deadlift].contains(first.pool)
                        else { continue }
                        let band: (lo: Double, hi: Double) = first.reps >= 8
                            ? (lo - 3, hi - 5) : (lo, hi)
                        days[di].slots[0].pct = lerp(band.lo, band.hi, t).rounded()
                        days[di].slots[0].rpe = t < 0.5 ? 7 : 8
                    }
                }
                if phase == .trans, blockPlan?.transScheme == .wave {
                    for di in days.indices {
                        guard let lift: LiftPool = [0: .squat, 1: .bench, 2: .deadlift][di],
                              let wave = waveOverride(week: i + 1, blockLen: b.weeks, lift: lift),
                              let first = days[di].slots.first, first.pool == lift, first.exIdx == 0
                        else { continue }
                        days[di].slots[0].sets = wave.sets
                        days[di].slots[0].reps = wave.reps
                        days[di].slots[0].pct = wave.pct
                        days[di].slots[0].rpe = wave.rpe
                    }
                }
                weeks.append(Week(
                    num: w, phase: phase, weekInBlock: i + 1, blockLen: b.weeks,
                    days: days
                ))
                w += 1
            }
        }

        var blocks: [Block] = []
        for b in rawBlocks {
            if isMeetTrack && b.phase == .real {
                if b.weeks - 1 > 0 { blocks.append(Block(phase: .real, weeks: b.weeks - 1)) }
                blocks.append(Block(phase: .meet, weeks: 1))
            } else {
                blocks.append(b)
            }
        }

        // With a custom block plan the true total is the plan's sum, not the arg.
        let actualTotal = rawBlocks.reduce(0) { $0 + $1.weeks }
        return Program(startPhase: startPhase, totalWeeks: actualTotal, fiveDay: fiveDay,
                       createdAt: Date(), blocks: blocks, weeks: weeks)
    }

    /// Hypertrophy off-season: meso-spine-driven builder (no meet week).
    static func buildHypertrophy(totalWeeks: Int, fiveDay: Bool) -> Program {
        let spine = hypSpine(totalWeeks: totalWeeks)
        var weeks: [Week] = []
        var weekInMeso = 0
        for (i, entry) in spine.enumerated() {
            switch entry {
            case .deload:
                weekInMeso = 0
                weeks.append(Week(num: i + 1, phase: .deload, weekInBlock: 1, blockLen: 1,
                                  days: dayTemplates(phase: .deload, t: 0, weeksOut: nil,
                                                     fiveDay: fiveDay)))
            case .work(let reps, let pct):
                weekInMeso += 1
                weeks.append(Week(num: i + 1, phase: .hyp, weekInBlock: weekInMeso, blockLen: 1,
                                  days: hypDays(reps: reps, pct: pct, weekInMeso: weekInMeso,
                                                fiveDay: fiveDay)))
            }
        }
        var program = Program(startPhase: .hypertrophy, totalWeeks: spine.count, fiveDay: fiveDay,
                              createdAt: Date(), blocks: [], weeks: weeks)
        program.renumberAndRegroup()   // block runs + in-block coordinates
        return program
    }

    // MARK: derived values

    static func slotName(_ slot: Slot, library: ExerciseLibrary) -> String {
        if let c = slot.custom { return c.isEmpty ? "Custom exercise" : c }
        return library.resolve(slot)?.name ?? "Exercise"
    }

    static func slotLoad(_ slot: Slot, maxes: Maxes, unit: Unit, library: ExerciseLibrary,
                         settings: ClientSettings? = nil) -> Double? {
        guard slot.custom == nil, let pct = slot.pct,
              let ex = library.resolve(slot), let mod = ex.mod else { return nil }
        var base = maxes.value(for: slot.pool)
        guard base > 0 else { return nil }
        var effectivePct = pct
        if let s = settings {
            let lift = s.lift(slot.pool)
            // Clamped at use so half-typed UI values can't produce absurd loads.
            if let tm = lift.trainingMaxPct { base *= min(110, max(50, tm)) / 100 }
            if let off = lift.intensityOffset { effectivePct += min(15, max(-15, off)) }
        }
        return roundLoad(base * (effectivePct / 100) * mod, unit: unit)
    }

    static func attempts(max: Double, unit: Unit,
                         profile: AttemptProfile? = nil) -> (opener: Double, second: Double, third: Double) {
        let p = (profile ?? AttemptProfile()).effective
        return (roundLoad(max * p.opener / 100, unit: unit),
                roundLoad(max * p.second / 100, unit: unit),
                roundLoad(max * p.third / 100, unit: unit))
    }

    // MARK: plain-text week export

    static func weekToText(client: Client, program: Program, week: Week,
                           library: ExerciseLibrary) -> String {
        var L: [String] = []
        var header = "\(client.name.uppercased()) — WEEK \(week.num) of \(program.weeks.count) — \(week.phase.label.uppercased())"
        if program.startPhase == .full || program.startPhase == .real {
            let out = program.weeks.count - week.num
            header += out == 0 ? " — MEET WEEK IS HERE" : " — \(out) WK\(out == 1 ? "" : "S") OUT"
        }
        L.append(header)
        // Calendar anchor so coach and lifter both see exactly WHICH week this is.
        if let start = client.startDate {
            let weekStart = DeliverySchedule.weekStart(startDate: start, weekNum: week.num)
            let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE MMM d"
            L.append("Week of \(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))")
        }
        L.append("Coach: block periodization · loads rise week to week — trust the percentages, cap sets at the listed RPE.")
        L.append("")
        for day in week.days {
            L.append(day.title)
            if day.slots.isEmpty { L.append("  Rest. Sleep 8+, eat, hydrate.") }
            for (i, s) in day.slots.enumerated() {
                var line = "  \(i + 1). \(slotName(s, library: library)) — \(s.sets)x\(s.reps)"
                let load = slotLoad(s, maxes: client.maxes, unit: client.unit, library: library,
                                    settings: client.settings)
                if let pct = s.pct {
                    // Show the % the lifter actually trains at (incl. any per-lift
                    // offset, clamped IDENTICALLY to slotLoad so the printed % and
                    // printed weight always agree).
                    let rawOff = load != nil ? (client.settings.lift(s.pool).intensityOffset ?? 0) : 0
                    let eff = pct + min(15, max(-15, rawOff))
                    line += eff == eff.rounded() ? " @ \(Int(eff))%" : String(format: " @ %.1f%%", eff)
                }
                if let load {
                    line += " → \(loadString(load, unit: client.unit))"
                }
                // Coach's convention: main/percentage work speaks RPE;
                // accessories speak RIR (reps in reserve = 10 − RPE).
                if s.pct == nil {
                    let rir = 10 - s.rpe
                    let rirStr = rir == rir.rounded() ? String(Int(rir)) : String(rir)
                    line += " · \(rirStr) RIR"
                } else {
                    let rpeStr = s.rpe == s.rpe.rounded() ? String(Int(s.rpe)) : String(s.rpe)
                    line += " · RPE \(rpeStr)"
                }
                if let note = s.note, !note.isEmpty { line += "  — \(note)" }
                if s.filmThis == true { line += "  📹 film this" }
                L.append(line)
            }
            L.append("")
        }
        if week.phase == .meet {
            L.append("MEET DAY ATTEMPTS")
            for (label, m) in [("Squat", client.maxes.squat), ("Bench", client.maxes.bench), ("Deadlift", client.maxes.deadlift)] {
                let a = attempts(max: m, unit: client.unit, profile: client.settings.attempts)
                func fmt(_ v: Double) -> String {
                    v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
                }
                L.append("  \(label): open \(fmt(a.opener)) / second \(fmt(a.second)) / third \(fmt(a.third)) \(client.unit.rawValue)")
            }
            L.append("")
        }
        if !week.note.isEmpty {
            L.append("COACH NOTES: \(week.note)")
            L.append("")
        }
        L.append("RPE guide: 7 = 3 reps left · 8 = 2 left · 9 = 1 left. If the % feels a full point harder than listed, drop the load.")
        return L.joined(separator: "\n")
    }
}
