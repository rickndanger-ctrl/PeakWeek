import Foundation

// MARK: - Peaking projection
// Reads the GENERATED program (never a parallel model of it), dates each
// peaking milestone off the day-one anchor, and grades the spacing against
// the evidence windows (fitness–fatigue-derived; τ₂ = 12 d "typical" profile).
// Methodology note: the two-factor model derives these CALENDAR RULES; it is
// not a live fitness/fatigue simulator and is never presented as one.

struct PeakProjection {

    struct Event: Identifiable {
        enum Kind: String {
            case lastHeavySquat = "Last heavy squat"
            case lastHeavyBench = "Last heavy bench"
            case lastHeavyDeadlift = "Last heavy deadlift"
            case openers = "Opener singles"
            case cessation = "Full cessation"
        }
        var id: String { kind.rawValue }
        var kind: Kind
        var date: Date
        var daysOut: Int
        /// Evidence window in days-out (inclusive).
        var window: ClosedRange<Int>
        var ok: Bool { window.contains(daysOut) }
        /// Plain coach-speak, no jargon: what happened and what ideal looks like.
        var detail: String {
            let sweet = "sweet spot is \(window.lowerBound)–\(window.upperBound) days before the meet"
            if ok { return "\(daysOut) days out — right where it should be" }
            if daysOut < window.lowerBound {
                return "\(daysOut) day\(daysOut == 1 ? "" : "s") out — cutting it close; \(sweet)"
            }
            return "\(daysOut) days out — earlier than ideal; \(sweet)"
        }
    }

    var events: [Event]
    /// Non-nil when the meet doesn't land at the end of the final week.
    var meetPlacementNote: String?

    var allInWindow: Bool { events.allSatisfy(\.ok) && meetPlacementNote == nil }

    /// Evidence windows (τ₂ = 12 d typical; per-lift recovery kinetics —
    /// deadlift needs the longest runway, bench the shortest).
    static let windows: [Event.Kind: ClosedRange<Int>] = [
        .lastHeavyDeadlift: 8...16,
        .lastHeavySquat: 6...12,
        .lastHeavyBench: 4...9,
        .openers: 4...10,
        .cessation: 2...7,
    ]

    static func compute(program: Program, startDate: Date, meetDate: Date,
                        calendar: Calendar = .current) -> PeakProjection? {
        guard program.startPhase == .full || program.startPhase == .real else { return nil }
        let meet = calendar.startOfDay(for: meetDate)

        func dayDate(weekNum: Int, dayIndex: Int) -> Date {
            let ws = DeliverySchedule.weekStart(startDate: startDate, weekNum: weekNum,
                                               calendar: calendar)
            return calendar.date(byAdding: .day, value: dayIndex, to: ws) ?? ws
        }
        func daysOut(_ d: Date) -> Int {
            calendar.dateComponents([.day], from: d, to: meet).day ?? 0
        }
        func event(_ kind: Event.Kind, week: Week, dayIndex: Int) -> Event {
            let d = dayDate(weekNum: week.num, dayIndex: dayIndex)
            return Event(kind: kind, date: d, daysOut: daysOut(d), window: windows[kind]!)
        }

        var events: [Event] = []

        // Days are located by CONTENT (first day carrying a %-loaded slot of
        // that lift), not fixed positions — coach-chosen day orders move the
        // real calendar dates and the projection must follow them.
        func liftDay(_ week: Week, _ pool: LiftPool, fallback: Int) -> Int {
            week.days.firstIndex { d in
                d.slots.contains { $0.pct != nil && $0.pool == pool }
            } ?? fallback
        }

        // The heavy-double week (realization, 2 out): last heavy SQ, BP, and
        // the LAST HEAVY DEADLIFT.
        if let heavy = program.weeks.first(where: { w in
            w.phase == .real && w.days.contains { $0.title.contains("LAST HEAVY DEADLIFT") }
        }) {
            events.append(event(.lastHeavySquat, week: heavy,
                                dayIndex: liftDay(heavy, .squat, fallback: 0)))
            events.append(event(.lastHeavyBench, week: heavy,
                                dayIndex: liftDay(heavy, .bench, fallback: 1)))
            events.append(event(.lastHeavyDeadlift, week: heavy,
                                dayIndex: liftDay(heavy, .deadlift, fallback: 2)))
        }

        // Opener week (realization, 1 out): the squat-opener day anchors the
        // window (bench shares it).
        if let openers = program.weeks.first(where: { w in
            w.phase == .real && w.days.contains { $0.title.contains("OPENER") }
        }) {
            events.append(event(.openers, week: openers,
                                dayIndex: liftDay(openers, .squat, fallback: 0)))
        }

        // Meet week: primers are days 1–2; cessation starts the day after.
        if let meetWeek = program.weeks.last, meetWeek.phase == .meet {
            let cessation = dayDate(weekNum: meetWeek.num, dayIndex: 2)
            events.append(Event(kind: .cessation, date: cessation,
                                daysOut: daysOut(cessation),
                                window: windows[.cessation]!))
        }

        // Meet placement: healthy = the back half of the final week, or the
        // day right after it (the classic Monday meet after a Sunday-ended
        // week). Only genuinely early or drifted placements get a note.
        var placementNote: String?
        if let last = program.weeks.last {
            let finalStart = DeliverySchedule.weekStart(startDate: startDate,
                                                        weekNum: last.num, calendar: calendar)
            let offset = calendar.dateComponents([.day], from: finalStart, to: meet).day ?? 0
            if offset < 0 || offset > 7 {
                placementNote = "The meet date doesn't line up with this program's final week. Easiest fix: click Plan from meet date — it re-dates day one so everything lands right."
            } else if offset < 4 {
                placementNote = "The meet falls early in the final week, which squeezes the last few rest days. Easiest fix: click Plan from meet date to re-date day one."
            }
        }

        guard !events.isEmpty || placementNote != nil else { return nil }
        return PeakProjection(events: events, meetPlacementNote: placementNote)
    }
}
