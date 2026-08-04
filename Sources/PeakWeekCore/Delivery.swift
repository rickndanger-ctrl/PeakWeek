import Foundation

// MARK: - Delivery preferences & send log models

public enum DeliveryMethod: String, Codable, CaseIterable, Identifiable {
    case messages, mail
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .messages: return "Messages"
        case .mail: return "Mail"
        }
    }
}

public enum DeliveryFormat: String, Codable, CaseIterable, Identifiable {
    case text, pdf, both
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .text: return "Text"
        case .pdf: return "PDF"
        case .both: return "Text + PDF"
        }
    }
}

public struct DeliveryPrefs: Codable, Hashable {
    public var autoSend: Bool = false           // master switch per client
    public var method: DeliveryMethod = .messages
    public var recipient: String = ""           // phone / iMessage handle / email
    public var format: DeliveryFormat = .text
    public var weekday: Int = 1                 // Calendar weekday: 1 = Sunday … 7 = Saturday
    public var hour: Int = 18                   // local time, 24h
    public var requireReview: Bool = true       // queue for approval instead of sending silently
    /// Mid-prep onboarding: auto-sending begins at this program week (weeks
    /// before it are simply never due — no queue, no skip records). nil = week 1.
    public var firstSendWeek: Int? = nil
    /// Set on regeneration when review is off: the NEXT due send queues for
    /// approval once, so a rebuild never fires an unconfirmed automatic send.
    public var forceReviewOnce: Bool? = nil

    // Tolerant decoding: any missing key falls back to its default, so adding
    // fields never breaks existing data.json files.
    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        autoSend = try c.decodeIfPresent(Bool.self, forKey: .autoSend) ?? false
        method = try c.decodeIfPresent(DeliveryMethod.self, forKey: .method) ?? .messages
        recipient = try c.decodeIfPresent(String.self, forKey: .recipient) ?? ""
        format = try c.decodeIfPresent(DeliveryFormat.self, forKey: .format) ?? .text
        weekday = try c.decodeIfPresent(Int.self, forKey: .weekday) ?? 1
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 18
        requireReview = try c.decodeIfPresent(Bool.self, forKey: .requireReview) ?? true
        firstSendWeek = try c.decodeIfPresent(Int.self, forKey: .firstSendWeek)
        forceReviewOnce = try c.decodeIfPresent(Bool.self, forKey: .forceReviewOnce)
    }
}

public enum SendStatus: Codable, Hashable {
    case sent
    case queued                          // waiting for coach approval (review mode)
    case failed(String)
    case skipped(String)                 // e.g. superseded by a newer due week

    public var label: String {
        switch self {
        case .sent: return "Sent"
        case .queued: return "Awaiting review"
        case .failed(let why): return "Failed — \(why)"
        case .skipped(let why): return "Skipped — \(why)"
        }
    }
    public var isTerminal: Bool {               // terminal records satisfy a due week
        if case .queued = self { return false }
        return true
    }
}

public struct SendRecord: Codable, Hashable, Identifiable {
    public var id: UUID = UUID()
    public var clientID: UUID
    public var clientName: String
    public var weekNum: Int
    public var date: Date
    public var method: DeliveryMethod
    public var status: SendStatus
    /// Identity of the program the record belongs to (program.createdAt).
    /// Regenerating a program starts fresh delivery bookkeeping; records from
    /// the old program neither satisfy nor block the new one.
    public var programStamp: Date? = nil
    /// True when this record's week was structurally REMOVED from the program
    /// (deload deleted after sending): the record stays as history but no
    /// longer counts as coverage for the week that inherits its number.
    public var weekRemoved: Bool? = nil

    public init(id: UUID = UUID(), clientID: UUID, clientName: String, weekNum: Int,
         date: Date, method: DeliveryMethod, status: SendStatus, programStamp: Date? = nil,
         weekRemoved: Bool? = nil) {
        self.id = id; self.clientID = clientID; self.clientName = clientName
        self.weekNum = weekNum; self.date = date; self.method = method
        self.status = status; self.programStamp = programStamp; self.weekRemoved = weekRemoved
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clientID = try c.decode(UUID.self, forKey: .clientID)
        clientName = try c.decodeIfPresent(String.self, forKey: .clientName) ?? ""
        weekNum = try c.decode(Int.self, forKey: .weekNum)
        date = try c.decode(Date.self, forKey: .date)
        method = try c.decodeIfPresent(DeliveryMethod.self, forKey: .method) ?? .messages
        status = try c.decodeIfPresent(SendStatus.self, forKey: .status) ?? .skipped("unknown")
        programStamp = try c.decodeIfPresent(Date.self, forKey: .programStamp)
        weekRemoved = try c.decodeIfPresent(Bool.self, forKey: .weekRemoved)
    }
}

// MARK: - Schedule math (pure, fully testable)

public enum DeliverySchedule {

    /// 00:00 local on day one of week `weekNum` (1-based). The program anchors
    /// to WHATEVER date the coach chose as day one — a lifter whose week runs
    /// Wednesday→Tuesday gets Wednesday-anchored weeks. (Old data stored
    /// Mondays; identical behavior for those.)
    public static func weekStart(startDate: Date, weekNum: Int, calendar: Calendar = .current) -> Date {
        let dayOne = calendar.startOfDay(for: startDate)
        return calendar.date(byAdding: .day, value: (weekNum - 1) * 7, to: dayOne)!
    }

    /// Convenience for suggesting a Monday (legacy default affordances).
    public static func mondayOfWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps)!
    }

    /// The moment week `weekNum`'s plan should go out: the occurrence of
    /// prefs.weekday/prefs.hour in the 7 days ENDING at the week's day one.
    /// (Send-day == anchor day → the morning the week begins; any other day →
    /// the matching day in the week BEFORE, e.g. Sunday-evening sends ahead of
    /// a Monday-anchored week.)
    public static func sendMoment(startDate: Date, weekNum: Int, prefs: DeliveryPrefs,
                           calendar: Calendar = .current) -> Date {
        let start = weekStart(startDate: startDate, weekNum: weekNum, calendar: calendar)
        let anchorWeekday = calendar.component(.weekday, from: start)
        let weekday = min(7, max(1, prefs.weekday))
        let hour = min(23, max(0, prefs.hour))
        var dayOffset = (weekday - anchorWeekday + 7) % 7   // anchor->0, next day->1 …
        if dayOffset > 0 { dayOffset -= 7 }                 // non-anchor days land BEFORE the week
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// True when the configured send lands ON the week's day-one weekday —
    /// meaning the plan arrives the day it's meant to START, not before it.
    /// (Any other send day lands in the week BEFORE by construction.) The
    /// coach gets warned so a morning lifter never trains day 1 blind.
    public static func sendLandsOnDayOne(startDate: Date, prefs: DeliveryPrefs,
                                  calendar: Calendar = .current) -> Bool {
        let anchor = calendar.component(.weekday, from: calendar.startOfDay(for: startDate))
        return min(7, max(1, prefs.weekday)) == anchor
    }

    /// Which program week contains `now` (1-based), or nil outside the program.
    public static func currentWeek(now: Date, startDate: Date, program: Program,
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
    public static func nextPlannedSend(now: Date, startDate: Date?, program: Program?,
                                prefs: DeliveryPrefs, records: [SendRecord],
                                calendar: Calendar = .current) -> (week: Int, moment: Date)? {
        guard let startDate, let program, !program.weeks.isEmpty else { return nil }
        let current = records.filter { $0.programStamp == program.createdAt }
        let covered = Set(current.filter { $0.status.isTerminal && $0.weekRemoved != true }.map(\.weekNum))
        // A stale first-send week beyond the program must not zero out sends.
        let firstWeek = min(prefs.firstSendWeek ?? 1, program.weeks.map(\.num).max() ?? 1)
        return program.weeks.lazy
            .filter { $0.num >= firstWeek && !covered.contains($0.num) }
            .map { ($0.num, sendMoment(startDate: startDate, weekNum: $0.num,
                                       prefs: prefs, calendar: calendar)) }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
    }

    /// A send that is due right now for one client.
    public struct DueSend: Equatable {
        public var weekNum: Int
        public var moment: Date
        public var supersededWeeks: [Int]       // older due-but-unsent weeks to mark skipped
        public var alreadyQueued: Bool          // a queued record for this week already exists
    }

    /// Catch-up policy: of all weeks whose send moment has passed and which have
    /// no terminal record yet, only the LATEST is sent; older ones are skipped.
    /// Only records stamped for THIS program count — regeneration always starts
    /// fresh bookkeeping (stamping predates every real-world send, so stamp-less
    /// records exist only in tests/fixtures). Records whose week was removed
    /// from the program no longer cover the week that inherited the number.
    public static func dueSend(now: Date, startDate: Date?, program: Program?,
                        prefs: DeliveryPrefs, records: [SendRecord],
                        calendar: Calendar = .current) -> DueSend? {
        guard prefs.autoSend,
              !prefs.recipient.trimmingCharacters(in: .whitespaces).isEmpty,
              let startDate, let program, !program.weeks.isEmpty else { return nil }

        let current = records.filter { $0.programStamp == program.createdAt }
        let covered = Set(current.filter { $0.status.isTerminal && $0.weekRemoved != true }.map(\.weekNum))
        let queuedWeeks = Set(current.filter {
            if case .queued = $0.status { return true }
            return false
        }.map(\.weekNum))
        // A stale first-send week beyond the program must not zero out sends.
        let firstWeek = min(prefs.firstSendWeek ?? 1, program.weeks.map(\.num).max() ?? 1)
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
