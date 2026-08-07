import Foundation
import AppKit
import UserNotifications

/// macOS notifications for the inbound pipeline. Flagged submissions notify;
/// clean ones stay silent (the Inbox badge carries the ambient count).
/// Authorization is requested LAZILY on the first flagged ingest — the
/// permission prompt appears when it has context, never at launch.
enum Notifier {

    /// Test seam (same pattern as SendBridge.dryRunCapture): when set,
    /// notifications are captured instead of posted, and no UserNotifications
    /// machinery is touched — UNUserNotificationCenter cannot run inside a
    /// bare test process.
    static var capture: ((_ title: String, _ body: String) -> Void)?

    static func flaggedSubmission(clientName: String, summary: String,
                                  flags: [String]) {
        post(title: "\(clientName) logged — worth a look",
             body: "\(summary)\n\(flags.joined(separator: " · "))")
    }

    static func noteReceived(clientName: String, body: String) {
        post(title: "Note from \(clientName)", body: String(body.prefix(160)))
    }

    /// An automated send did not reach the lifter. Loud on purpose: failures
    /// are terminal, so nothing retries this without the coach.
    static func sendFailed(clientName: String, weekNum: Int, reason: String) {
        post(title: "Week \(weekNum) did NOT reach \(clientName)",
             body: "\(reason)\nOpen Deliveries to retry.")
    }

    /// A send is sitting in the review queue. It will not go out on its own.
    static func sendQueued(clientName: String, weekNum: Int) {
        post(title: "Week \(weekNum) for \(clientName) is waiting for you",
             body: "It won't send until you approve it in Deliveries.")
    }

    private static func post(title: String, body: String) {
        if let capture {
            capture(title, body)
            return
        }
        // A real app context is required: bare `swift test`/`swift run`
        // processes crash inside UNUserNotificationCenter.
        guard Bundle.main.bundleIdentifier != nil, NSApp != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}
