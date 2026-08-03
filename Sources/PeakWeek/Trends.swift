import Foundation

/// e1RM trend signals per lift, computed from the client's log.
///
/// Doctrine (see the powerlifting skill):
/// - Judge the trend BLOCK-OVER-BLOCK, never week-over-week — accumulation
///   fatigue depresses expression on purpose, so weekly wobble means nothing.
/// - Deload and meet weeks are excluded — light weeks say nothing.
/// - A stall is a CONVERSATION, not a scheme swap: this type surfaces the
///   signal and prompts a check-in. It never prescribes a fix.
enum Trends {

    struct Point: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let e1RM: Double          // comp-normalized
        let isVariation: Bool     // estimated through a load modifier
        let cleanSingle: Bool
    }

    struct BlockBest: Identifiable, Hashable {
        let id: Int               // ordinal position of the block in the program
        let label: String         // "Accumulation", "Transmutation", …
        let best: Double
        let count: Int            // logged points inside the block
    }

    enum Verdict: Hashable {
        case insufficient         // not enough data to judge a block honestly
        case up(Double)           // pct change, latest block vs the one before
        case flat(Double)
        case down(Double)
    }

    struct LiftTrend {
        let lift: LiftPool
        let points: [Point]
        let blockBests: [BlockBest]
        let verdict: Verdict
        let rpeDrift: Double?     // mean(reported − prescribed) over recent paired sets
        let checkIn: Bool         // stall doctrine: time for a whole-picture conversation
    }

    /// Minimum logged points a block needs before its best is trusted for a
    /// block-over-block comparison. One point can be a bad day; two is a trend.
    static let minPointsPerBlock = 2

    /// Reported RPE arriving this much above prescribed (average of the last
    /// paired sets) reads as fatigue masking — "cross-check wellness first".
    static let driftThreshold = 0.75

    static func compute(lift: LiftPool, logs: [LiftLogEntry],
                        program: Program?, startDate: Date?,
                        calendar: Calendar = .current) -> LiftTrend {
        let entries = logs.filter { $0.lift == lift }.sorted { $0.date < $1.date }
        let points: [Point] = entries.compactMap { e in
            guard let v = e.compE1RM else { return nil }
            return Point(id: e.id, date: e.date, e1RM: v,
                         isVariation: e.isVariation, cleanSingle: e.cleanSingle)
        }

        // Bucket points into the program's training blocks by date. Deload and
        // meet blocks are skipped for judgement (light weeks say nothing), and
        // VERDICTS only trust comp-measured points — variation e1RMs run
        // through a ±3-5% modifier estimate, which would swamp a ±1% verdict.
        let compPoints = points.filter { !$0.isVariation }
        var bests: [BlockBest] = []
        var lightRanges: [(Date, Date)] = []       // deload/meet calendar spans
        var programSpan: (Date, Date)? = nil
        if let program, let startDate, !program.blocks.isEmpty {
            var weekCursor = 1
            for (ordinal, block) in program.blocks.enumerated() {
                let firstWeek = weekCursor
                weekCursor += block.weeks
                guard block.weeks > 0 else { continue }
                let s = DeliverySchedule.weekStart(startDate: startDate,
                                                  weekNum: firstWeek, calendar: calendar)
                let e = DeliverySchedule.weekStart(startDate: startDate,
                                                  weekNum: firstWeek + block.weeks, calendar: calendar)
                if block.phase == .deload || block.phase == .meet {
                    lightRanges.append((s, e))
                    continue
                }
                let inBlock = compPoints.filter { $0.date >= s && $0.date < e }
                if let best = inBlock.map(\.e1RM).max() {
                    bests.append(BlockBest(id: ordinal, label: block.phase.label,
                                           best: best, count: inBlock.count))
                }
            }
            let start = DeliverySchedule.weekStart(startDate: startDate,
                                                   weekNum: 1, calendar: calendar)
            let end = DeliverySchedule.weekStart(startDate: startDate,
                                                 weekNum: weekCursor, calendar: calendar)
            programSpan = (start, end)
        }

        let verdict: Verdict
        if bests.count >= 2 {
            let prev = bests[bests.count - 2], cur = bests[bests.count - 1]
            if prev.count >= minPointsPerBlock, cur.count >= minPointsPerBlock, prev.best > 0 {
                let change = (cur.best - prev.best) / prev.best * 100
                if change >= 1 { verdict = .up(change) }
                else if change <= -1 { verdict = .down(change) }
                else { verdict = .flat(change) }
            } else {
                verdict = .insufficient
            }
        } else {
            verdict = .insufficient
        }

        // Fatigue masking: prescribed @8 repeatedly arriving @9+. Only sets
        // where both numbers exist count; clean singles are max attempts, not
        // programmed work. Deload/meet-week sets are excluded (a 62% set
        // "feeling like a 7" is normal recovery, not a signal), and — when a
        // program exists — so are sets from outside its calendar span, so a
        // stale block never masquerades as a current fatigue signal.
        let paired = entries.compactMap { e -> Double? in
            guard let a = e.rpe, let p = e.prescribedRPE, !e.cleanSingle else { return nil }
            if lightRanges.contains(where: { e.date >= $0.0 && e.date < $0.1 }) { return nil }
            if let span = programSpan, !(e.date >= span.0 && e.date < span.1) { return nil }
            return a - p
        }
        let recent = paired.suffix(3)
        let drift: Double? = recent.count >= 3
            ? recent.reduce(0, +) / Double(recent.count) : nil

        let isDown: Bool = { if case .down = verdict { return true }; return false }()
        let isFlat: Bool = { if case .flat = verdict { return true }; return false }()
        let hotRPE = (drift ?? 0) >= driftThreshold
        // Check-in fires on: e1RM down across a block, OR flat with hot RPE
        // (grinding to stand still), OR strong drift alone (≥ +1 average).
        let checkIn = isDown || (isFlat && hotRPE) || (drift ?? 0) >= 1.0

        return LiftTrend(lift: lift, points: points, blockBests: bests,
                         verdict: verdict, rpeDrift: drift, checkIn: checkIn)
    }
}
