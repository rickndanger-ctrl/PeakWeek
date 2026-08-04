import Foundation

/// Sanity checks run on every client-submitted entry at ingest. Doctrine:
/// AUTO-LOG EVERYTHING, flag what looks off — the coach reviews, the data is
/// never held hostage. Pure function, entry already converted to the
/// client's unit.
enum AnomalyCheck {

    // Named thresholds — tuning happens here, nowhere else.
    static let e1RMSpikeFactor = 1.08        // vs best recent comp point
    static let e1RMNoHistoryFactor = 1.15    // vs stored max, when history is thin
    static let overMaxFactor = 1.05          // load vs stored max × modifier
    static let recentWindowDays = 90.0
    static let unitMixTolerance = 0.05       // ±5% around the kg/lb-confused value
    static let medianSampleSize = 5

    static func check(entry: LiftLogEntry, client: Client,
                      now: Date = Date()) -> [String] {
        var flags: [String] = []
        let maxVal = client.maxes.value(for: entry.lift)
        let mod = entry.loadMod ?? 1
        let effMax = maxVal * mod

        // 1. e1RM spike vs the recent trend (comp-measured points only).
        if let e = entry.compE1RM {
            let windowStart = entry.date.addingTimeInterval(-recentWindowDays * 86400)
            let recent = client.logs
                .filter { $0.id != entry.id && $0.lift == entry.lift && !$0.isVariation
                          && $0.date >= windowStart && $0.date <= entry.date }
                .compactMap(\.compE1RM)
            if recent.count >= 2, let best = recent.max() {
                if e > best * e1RMSpikeFactor {
                    let pct = Int(((e / best) - 1) * 100)
                    flags.append("e1RM \(pct)% above the recent best — big jump")
                }
            } else if maxVal > 0, !entry.isVariation, e > maxVal * e1RMNoHistoryFactor {
                flags.append("e1RM well above the stored max")
            }
        }

        // 2. Load above the stored max (through the variation modifier).
        if effMax > 0, entry.load > effMax * overMaxFactor {
            flags.append("load above the stored max")
        }

        // 3. Possible kg/lb mix-up: the load × or ÷ 2.2046 lands right on the
        // expected number. (A correct load can't trip this — it sits at the
        // expected value, not 2.2× away from it.)
        let expected: Double? = {
            if let pct = entry.prescribedPct, effMax > 0 { return effMax * pct / 100 }
            let prior = client.logs
                .filter { $0.id != entry.id && $0.lift == entry.lift && $0.load > 0 }
                .sorted { $0.date > $1.date }
                .prefix(medianSampleSize)
                .map(\.load)
                .sorted()
            guard !prior.isEmpty else { return nil }
            return prior[prior.count / 2]
        }()
        if let exp = expected, exp > 0, entry.load > 0 {
            let asLb = entry.load * Maxes.lbPerKg
            let asKg = entry.load / Maxes.lbPerKg
            if abs(asLb - exp) <= unitMixTolerance * exp
                || abs(asKg - exp) <= unitMixTolerance * exp {
                flags.append("possible kg/lb mix-up")
            }
        }

        // 4. Duplicate: same lift, same calendar day, same reps, load within
        // one plate step. (Idempotent submission IDs catch retries; this
        // catches a double-tap that minted two IDs.)
        let dayMatch = client.logs.contains {
            $0.id != entry.id && $0.submissionID != entry.submissionID
                && $0.lift == entry.lift && $0.reps == entry.reps
                && Calendar.current.isDate($0.date, inSameDayAs: entry.date)
                && abs($0.load - entry.load) <= client.unit.step
        }
        if dayMatch { flags.append("looks like a duplicate of an entry that day") }

        // 5. Multi-rep set with a prescribed RPE but none reported (soft).
        if entry.reps > 1, entry.rpe == nil, entry.prescribedRPE != nil {
            flags.append("no RPE reported")
        }

        return flags
    }
}
