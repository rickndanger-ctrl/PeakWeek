import Foundation
import BackgroundTasks
import UserNotifications
import PeakWeekCore

/// "Your new week is here" — without a push server. iOS background refresh
/// polls the pipe opportunistically; when the published week changes, a
/// LOCAL notification fires. (True APNs push is a later upgrade needing an
/// Apple push key; this needs nothing.)
enum WeekWatch {
    static let taskID = "com.peakweek.client.refresh"
    private static let lastSeenKey = "pw.lastSeenPublishedAt"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule()   // always re-arm
        let work = Task {
            await checkForNewWeek()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// Compare the pipe's published week against the last one we told the
    /// lifter about. Also called on foreground refresh so an in-app sighting
    /// counts as "seen" and never double-notifies.
    static func checkForNewWeek() async {
        guard let token = await MainActor.run(body: { Keychain.token() }) else { return }
        guard let envelope = try? await API.fetchWeek(token: token),
              let publishedAt = envelope.publishedAt else { return }
        let stamp = ISO8601DateFormatter().string(from: publishedAt)
        let last = UserDefaults.standard.string(forKey: lastSeenKey)
        guard stamp != last else { return }
        UserDefaults.standard.set(stamp, forKey: lastSeenKey)
        guard last != nil else { return }   // first sight ever: no fanfare

        let content = UNMutableNotificationContent()
        content.title = "Your new week is here"
        if let week = envelope.payload {
            content.body = "Week \(week.weekNum) of \(week.totalWeeks) — \(week.phaseLabel). Open PeakWeek to see the plan."
        } else {
            content.body = "Your coach published a new training week."
        }
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "new-week-\(stamp)",
                                  content: content, trigger: nil),
            withCompletionHandler: nil)
    }

    /// Foreground sighting: mark the current week as seen without notifying.
    static func markSeen(publishedAt: Date?) {
        guard let publishedAt else { return }
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: publishedAt),
                                  forKey: lastSeenKey)
    }
}
