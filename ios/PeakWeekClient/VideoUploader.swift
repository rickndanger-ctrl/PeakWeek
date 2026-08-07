import Foundation
import PeakWeekCore

/// Video uploads on a BACKGROUND URLSession.
///
/// This matters more than it looks. The normal shape of a gym set is: film it,
/// tap Send, put the phone in your pocket. On a foreground session iOS
/// suspends the app within seconds of that and the transfer dies — and since
/// the PUT isn't resumable, the retry starts again from byte zero. A 25 MB clip
/// on gym LTE never finishes that way.
///
/// A background session is handed to the system, survives app suspension, and
/// relaunches the app to report completion. The outbox stays the safety net for
/// anything the system does give up on (notably a user force-quit, which
/// cancels background transfers outright).
@MainActor
final class VideoUploader: NSObject {
    static let shared = VideoUploader()

    static let sessionID = "com.peakweek.client.upload"

    /// Set by the app delegate when iOS wakes us purely to finish transfers;
    /// must be called once the session reports it has drained its events.
    var backgroundCompletionHandler: (() -> Void)?

    /// Told about every finished upload: (submissionID, error). Wired to the
    /// outbox so a completion can call video-done and mark the item delivered.
    var onFinished: ((UUID, Error?) -> Void)?

    private var session: URLSession!

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.background(withIdentifier: Self.sessionID)
        cfg.isDiscretionary = false          // she pressed Send; don't wait for wifi
        cfg.sessionSendsLaunchEvents = true
        cfg.timeoutIntervalForResource = 24 * 3600
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    /// Hand a file to the system to deliver. Returns immediately.
    func upload(fileURL: URL, ticket: API.UploadTicket, submissionID: UUID) {
        guard let url = URL(string: ticket.url) else {
            onFinished?(submissionID, APIError(message: "bad upload URL"))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        let task = session.uploadTask(with: req, fromFile: fileURL)
        // Background tasks outlive this process; the id is how we find our way
        // back to the right outbox row after a relaunch.
        task.taskDescription = submissionID.uuidString
        task.resume()
    }

    /// Submission ids the system is currently carrying, so a flush doesn't
    /// start a second transfer for something already in flight.
    func activeSubmissionIDs() async -> Set<UUID> {
        let tasks = await session.allTasks
        return Set(tasks.compactMap { task in
            task.taskDescription.flatMap(UUID.init)
        })
    }
}

extension VideoUploader: URLSessionDataDelegate {

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                               didCompleteWithError error: Error?) {
        let id = task.taskDescription.flatMap(UUID.init)
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        let failure: Error? = {
            if let error { return error }
            guard (200...299).contains(status) else {
                return APIError(message: "Video upload failed (\(status)) — will retry.")
            }
            return nil
        }()
        Task { @MainActor in
            guard let id else { return }
            VideoUploader.shared.onFinished?(id, failure)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            let handler = VideoUploader.shared.backgroundCompletionHandler
            VideoUploader.shared.backgroundCompletionHandler = nil
            handler?()
        }
    }
}
