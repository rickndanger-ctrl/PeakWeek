import Foundation

/// The structured week the coach app publishes for the client app to render:
/// exactly ONE week — the one that was just sent — never the whole program.
/// (Week-by-week is doctrine; the server keeps only the latest row per
/// client, so the app can never browse ahead.) Built from the same helpers
/// the text/PDF renderers use; the golden-locked weekToText is untouched.
public struct PublishedWeek: Codable, Hashable {

    /// A slot the lifter can log against — prefills the phone's logging form
    /// with what was prescribed, which is what makes drift detection work.
    public struct Loggable: Codable, Hashable {
        public var lift: LiftPool
        public var exerciseName: String
        public var sets: Int
        public var reps: Int
        public var pct: Double?          // effective (offset-clamped) %
        public var rpe: Double?
        public var load: Double?         // rounded target, in `unit`
        public var slotIndex: Int        // position within the day

        public init(lift: LiftPool, exerciseName: String, sets: Int, reps: Int,
                    pct: Double? = nil, rpe: Double? = nil, load: Double? = nil,
                    slotIndex: Int) {
            self.lift = lift; self.exerciseName = exerciseName
            self.sets = sets; self.reps = reps
            self.pct = pct; self.rpe = rpe; self.load = load
            self.slotIndex = slotIndex
        }
    }

    public struct Day: Codable, Hashable {
        public var title: String
        public var lines: [String]       // display rows, one per slot
        public var loggables: [Loggable]

        public init(title: String, lines: [String], loggables: [Loggable]) {
            self.title = title; self.lines = lines; self.loggables = loggables
        }
    }

    public var weekNum: Int
    public var totalWeeks: Int
    public var phaseLabel: String
    public var weeksOut: Int?
    public var programStamp: Date
    public var unit: Unit
    public var dateRange: String
    public var days: [Day]
    public var weekNote: String
    public var footer: String

    public init(weekNum: Int, totalWeeks: Int, phaseLabel: String,
                weeksOut: Int?, programStamp: Date, unit: Unit,
                dateRange: String, days: [Day], weekNote: String,
                footer: String) {
        self.weekNum = weekNum; self.totalWeeks = totalWeeks
        self.phaseLabel = phaseLabel; self.weeksOut = weeksOut
        self.programStamp = programStamp; self.unit = unit
        self.dateRange = dateRange; self.days = days
        self.weekNote = weekNote; self.footer = footer
    }
}

public extension Engine {

    /// Structured render of one week for the client app. Reuses slotName /
    /// slotLoad / the effective-% clamp — never weekToText (golden-locked).
    static func weekToPublished(client: Client, program: Program, week: Week,
                                library: ExerciseLibrary,
                                calendar: Calendar = .current) -> PublishedWeek {
        var days: [PublishedWeek.Day] = []
        for day in week.days {
            var lines: [String] = []
            var loggables: [PublishedWeek.Loggable] = []
            for (si, slot) in day.slots.enumerated() {
                let name = slotName(slot, library: library)
                let load = slotLoad(slot, maxes: client.maxes, unit: client.unit,
                                    library: library, settings: client.settings)
                var line = "\(name) — \(slot.sets)×\(slot.reps)"
                if let pct = slot.pct {
                    let off = client.settings.lift(slot.pool).intensityOffset ?? 0
                    let eff = pct + min(15, max(-15, off))
                    line += String(format: eff == eff.rounded() ? " @ %.0f%%" : " @ %.1f%%", eff)
                    if let load {
                        line += " → \(loadString(load, unit: client.unit))"
                    }
                    line += slot.rpe == slot.rpe.rounded()
                        ? " · RPE \(Int(slot.rpe))" : String(format: " · RPE %.1f", slot.rpe)
                    if slot.custom == nil, [.squat, .bench, .deadlift].contains(slot.pool) {
                        loggables.append(PublishedWeek.Loggable(
                            lift: slot.pool, exerciseName: name,
                            sets: slot.sets, reps: slot.reps,
                            pct: eff, rpe: slot.rpe, load: load, slotIndex: si))
                    }
                } else {
                    let rir = 10 - slot.rpe
                    line += rir == rir.rounded()
                        ? " · \(Int(rir)) RIR" : String(format: " · %.1f RIR", rir)
                }
                if let note = slot.note, !note.isEmpty { line += "  (\(note))" }
                lines.append(line)
            }
            if day.slots.isEmpty {
                lines.append("Rest. Sleep 8+, eat, hydrate.")
            }
            days.append(PublishedWeek.Day(title: day.title, lines: lines,
                                          loggables: loggables))
        }

        var weeksOut: Int?
        if program.startPhase == .full || program.startPhase == .real {
            let out = program.weeks.count - week.num
            if out > 0 { weeksOut = out }
        }

        var dateRange = ""
        if let start = client.startDate {
            let ws = DeliverySchedule.weekStart(startDate: start,
                                               weekNum: week.num, calendar: calendar)
            let we = calendar.date(byAdding: .day, value: 6, to: ws) ?? ws
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            dateRange = "\(fmt.string(from: ws)) – \(fmt.string(from: we))"
        }

        return PublishedWeek(
            weekNum: week.num,
            totalWeeks: program.weeks.count,
            phaseLabel: week.phase.label,
            weeksOut: weeksOut,
            programStamp: program.createdAt,
            unit: client.unit,
            dateRange: dateRange,
            days: days,
            weekNote: week.note,
            footer: "Log your top sets in the app — your coach sees them the same day.")
    }
}
