import Foundation

// MARK: - Delivery preferences & send log models

enum DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case messages, mail
    var id: String { rawValue }
    var label: String {
        switch self {
        case .messages: return "Messages"
        case .mail: return "Mail"
        }
    }
}

enum DeliveryFormat: String, Codable, CaseIterable, Identifiable {
    case text, pdf, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .text: return "Text"
        case .pdf: return "PDF"
        case .both: return "Text + PDF"
        }
    }
}

struct DeliveryPrefs: Codable, Hashable {
    var autoSend: Bool = false           // master switch per client
    var method: DeliveryMethod = .messages
    var recipient: String = ""           // phone / iMessage handle / email
    var format: DeliveryFormat = .text
    var weekday: Int = 1                 // Calendar weekday: 1 = Sunday … 7 = Saturday
    var hour: Int = 18                   // local time, 24h
    var requireReview: Bool = true       // queue for approval instead of sending silently
    /// Mid-prep onboarding: auto-sending begins at this program week (weeks
    /// before it are simply never due — no queue, no skip records). nil = week 1.
    var firstSendWeek: Int? = nil

    // Tolerant decoding: any missing key falls back to its default, so adding
    // fields never breaks existing data.json files.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoSend = try c.decodeIfPresent(Bool.self, forKey: .autoSend) ?? false
        method = try c.decodeIfPresent(DeliveryMethod.self, forKey: .method) ?? .messages
        recipient = try c.decodeIfPresent(String.self, forKey: .recipient) ?? ""
        format = try c.decodeIfPresent(DeliveryFormat.self, forKey: .format) ?? .text
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? 1
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 18
        requireReview = try c.decodeIfPresent(Bool.self, forKey: .requireReview) ?? true
        firstSendWeek = try c.decodeIfPresent(Int.self, forKey: .firstSendWeek)
    }
}

enum SendStatus: Codable, Hashable {
    case sent
    case queued                          // waiting for coach approval (review mode)
    case failed(String)
    case skipped(String)                 // e.g. superseded by a newer due week

    var label: String {
        switch self {
        case .sent: return "Sent"
        case .queued: return "Awaiting review"
        case .failed(let why): return "Failed — \(why)"
        case .skipped(let why): return "Skipped — \(why)"
        }
    }
    var isTerminal: Bool {               // terminal records satisfy a due week
        if case .queued = self { return false }
        return true
    }
}

struct SendRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var clientID: UUID
    var clientName: String
    var weekNum: Int
    var date: Date
    var method: DeliveryMethod
    var status: SendStatus
    /// Identity of the program the record belongs to (program.createdAt).
    /// Regenerating a program starts fresh delivery bookkeeping; records from
    /// the old program neither satisfy nor block the new one.
    var programStamp: Date? = nil

    init(id: UUID = UUID(), clientID: UUID, clientName: String, weekNum: Int,
         date: Date, method: DeliveryMethod, status: SendStatus, programStamp: Date? = nil) {
        self.id = id; self.clientID = clientID; self.clientName = clientName
        self.weekNum = weekNum; self.date = date; self.method = method
        self.status = status; self.programStamp = programStamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clientID = try c.decode(UUID.self, forKey: .clientID)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        weekNum = try c.decode(Int.self, forKey: .weekNum)
        date = try c.decode(Date.self, forKey: .date)
        method = try c.decodeIfPresent(DeliveryMethod.self, forKey: .method) ?? .messages
        status = try c.decodeIfPresent(SendStatus.self, forKey: .status) ?? .skipped("unknown")
        programStamp = try c.decodeIfPresent(Date.self, forKey: .programStamp)
    }
}

// MARK: - Schedule math (pure, fully testable)

enum DeliverySchedule {

    /// Monday 00:00 local of the week `weekNum` (1-based) for a program anchored
    /// at `startDate` (itself normalized to a Monday).
    static func weekStart(startDate: Date, weekNum: Int, calendar: Calendar = .current) -> Date {
        let monday = mondayOfWeek(containing: startDate, calendar: calendar)
        return calendar.date(byAdding: .day, value: (weekNum - 1) * 7, to: monday)!
    }

    static func mondayOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)!
    }

    /// The moment week `weekNum`'s plan should go out: the occurrence of
    /// prefs.weekday/prefs.hour in the 7 days ENDING at the week's Monday.
    /// (Sunday 18:00 prefs → the evening before the training week begins.
    ///  Monday prefs → the morning the week begins.)
    static func sendMoment(startDate: Date, weekNum: Int, prefs: DeliveryPrefs,
                           calendar: Calendar = .current) -> Date {
        let start = weekStart(startDate: startDate, weekNum: weekNum, calendar: calendar)
        // Walk back from Monday 00:00 to the requested weekday at the requested hour.
        // Monday itself counts as "this week" (offset 0), Sunday as -1 day, etc.
        let weekdayOfMonday = 2
        let weekday = min(7, max(1, prefs.weekday))
        let hour = min(23, max(0, prefs.hour))
        var dayOffset = (weekday - weekdayOfMonday + 7) % 7        // Mon->0, Tue->1 … Sun->6
        if dayOffset > 0 { dayOffset -= 7 }                        // Tue..Sun land BEFORE the week
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// Which program week contains `now` (1-based), or nil outside the program.
    static func currentWeek(now: Date, startDate: Date, program: Program,
                            calendar: Calendar = .current) -> Int? {
        for week in program.weeks {
            let start = weekStart(startDate: startDate, weekNum: week.num, calendar: calendar)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            if now >= start && now < end { return week.num }
        }
        return nil
    }

    /// The next auto-send on the calendar (week + moment), honoring
    /// firstSendWeek and already-covered weeks. nil when nothing remains.
    static func nextPlannedSend(now: Date, startDate: Date?, program: Program?,
                                prefs: DeliveryPrefs, records: [SendRecord],
                                calendar: Calendar = .current) -> (week: Int, moment: Date)? {
        guard let startDate, let program, !program.weeks.isEmpty else { return nil }
        let current = records.filter { $0.programStamp == nil || $0.programStamp == program.createdAt }
        let covered = Set(current.filter { $0.status.isTerminal }.map(\.weekNum))
        let firstWeek = prefs.firstSendWeek ?? 1
        return program.weeks.lazy
            .filter { $0.num >= firstWeek && !covered.contains($0.num) }
            .map { ($0.num, sendMoment(startDate: startDate, weekNum: $0.num,
                                       prefs: prefs, calendar: calendar)) }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
    }

    /// A send that is due right now for one client.
    struct DueSend: Equatable {
        var weekNum: Int
        var moment: Date
        var supersededWeeks: [Int]       // older due-but-unsent weeks to mark skipped
        var alreadyQueued: Bool          // a queued record for this week already exists
    }

    /// Catch-up policy: of all weeks whose send moment has passed and which have
    /// no terminal record yet, only the LATEST is sent; older ones are skipped.
    /// Only records belonging to the CURRENT program (programStamp) count;
    /// legacy stamp-less records match any program.
    static func dueSend(now: Date, startDate: Date?, program: Program?,
                        prefs: DeliveryPrefs, records: [SendRecord],
                        calendar: Calendar = .current) -> DueSend? {
        guard prefs.autoSend,
              !prefs.recipient.trimmingCharacters(in: .whitespaces).isEmpty,
              let startDate, let program, !program.weeks.isEmpty else { return nil }

        let current = records.filter { $0.programStamp == nil || $0.programStamp == program.createdAt }
        let covered = Set(current.filter { $0.status.isTerminal }.map(\.weekNum))
        let queuedWeeks = Set(current.filter {
            if case .queued = $0.status { return true }
            return false
        }.map(\.weekNum))
        let firstWeek = prefs.firstSendWeek ?? 1
        var due: [(week: Int, moment: Date)] = []
        for week in program.weeks where week.num >= firstWeek {
            let moment = sendMoment(startDate: startDate, weekNum: week.num,
                                    prefs: prefs, calendar: calendar)
            if moment <= now, !covered.contains(week.num) {
                due.append((week.num, moment))
            }
        }
        guard let latest = due.max(by: { $0.week < $1.week }) else { return nil }
        let superseded = due.map(\.week).filter { $0 != latest.week }.sorted()
        return DueSend(weekNum: latest.week, moment: latest.moment,
                       supersededWeeks: superseded,
                       alreadyQueued: queuedWeeks.contains(latest.week))
    }
}
