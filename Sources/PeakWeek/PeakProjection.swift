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
        var detail: String {
            let range = "\(window.lowerBound)–\(window.upperBound) d"
            if ok { return "\(daysOut) d out · in window (\(range))" }
            let drift = daysOut < window.lowerBound
                ? "\(window.lowerBound - daysOut) d too close to the meet"
                : "\(daysOut - window.upperBound) d too far out"
            return "\(daysOut) d out · outside \(range) — \(drift)"
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

        // The heavy-double week (realization, 2 out): last heavy SQ (day 1),
        // BP (day 2), and the LAST HEAVY DEADLIFT (day 3).
        if let heavy = program.weeks.first(where: { w in
            w.phase == .real && w.days.contains { $0.title.contains("LAST HEAVY DEADLIFT") }
        }) {
            events.append(event(.lastHeavySquat, week: heavy, dayIndex: 0))
            events.append(event(.lastHeavyBench, week: heavy, dayIndex: 1))
            events.append(event(.lastHeavyDeadlift, week: heavy, dayIndex: 2))
        }

        // Opener week (realization, 1 out): squat opener day 1 (bench day 2
        // shares the window).
        if let openers = program.weeks.first(where: { w in
            w.phase == .real && w.days.contains { $0.title.contains("OPENER") }
        }) {
            events.append(event(.openers, week: openers, dayIndex: 0))
        }

        // Meet week: primers are days 1–2; cessation starts the day after.
        if let meetWeek = program.weeks.last, meetWeek.phase == .meet {
            let cessation = dayDate(weekNum: meetWeek.num, dayIndex: 2)
            events.append(Event(kind: .cessation, date: cessation,
                                daysOut: daysOut(cessation),
                                window: windows[.cessation]!))
        }

        // Meet placement: the meet should land at the END of the final week.
        var placementNote: String?
        if let last = program.weeks.last {
            let finalStart = DeliverySchedule.weekStart(startDate: startDate,
                                                        weekNum: last.num, calendar: calendar)
            let offset = calendar.dateComponents([.day], from: finalStart, to: meet).day ?? 0
            if offset < 0 || offset > 6 {
                placementNote = "The meet date falls OUTSIDE the program's final week — re-date day one (Plan from meet date aligns this automatically)."
            } else if offset < 4 {
                placementNote = "The meet lands on day \(offset + 1) of the final week — early. Best: re-date day one so the meet falls at the week's end (Plan from meet date does this)."
            }
        }

        guard !events.isEmpty || placementNote != nil else { return nil }
        return PeakProjection(events: events, meetPlacementNote: placementNote)
    }
}
