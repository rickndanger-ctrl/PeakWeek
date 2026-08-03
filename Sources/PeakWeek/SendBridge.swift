import Foundation
import AppKit

// MARK: - Outbound bridges: Messages & Mail via Apple events.
// macOS asks the user once for Automation permission per target app.

enum SendError: Error, LocalizedError {
    case emptyRecipient
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyRecipient: return "No recipient configured"
        case .scriptFailed(let msg): return msg
        }
    }
}

enum SendBridge {

    /// Tests set this so nothing ever reaches a real person. When non-nil,
    /// scripts are captured here instead of executed.
    static var dryRunCapture: ((String) -> Void)?

    // MARK: public API

    static func send(via method: DeliveryMethod, to recipient: String,
                     subject: String, text: String?, attachment: URL?) -> Result<Void, SendError> {
        let trimmed = recipient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.emptyRecipient) }
        switch method {
        case .messages:
            return run(messagesScript(recipient: trimmed, text: text, attachment: attachment))
        case .mail:
            return run(mailScript(recipient: trimmed, subject: subject,
                                  body: text ?? "", attachment: attachment))
        }
    }

    // MARK: script builders (internal for tests)

    static func messagesScript(recipient: String, text: String?, attachment: URL?) -> String {
        var lines = [
            "tell application \"Messages\"",
            "  set targetService to 1st account whose service type = iMessage",
            "  set targetBuddy to participant \"\(esc(recipient))\" of targetService",
        ]
        // Attachment FIRST: if the script fails partway, nothing has been sent
        // yet (a retry after a failed text would otherwise duplicate the text).
        if let attachment {
            lines.append("  send POSIX file \"\(esc(attachment.path))\" to targetBuddy")
        }
        if let text, !text.isEmpty {
            lines.append("  send \"\(esc(text))\" to targetBuddy")
        }
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    static func mailScript(recipient: String, subject: String, body: String, attachment: URL?) -> String {
        var lines = [
            "tell application \"Mail\"",
            "  set newMessage to make new outgoing message with properties {subject:\"\(esc(subject))\", content:\"\(esc(body))\" & return & return, visible:false}",
            "  tell newMessage",
            "    make new to recipient at end of to recipients with properties {address:\"\(esc(recipient))\"}",
        ]
        if let attachment {
            lines.append("    tell content to make new attachment with properties {file name:POSIX file \"\(esc(attachment.path))\"} at after the last paragraph")
        }
        lines.append(contentsOf: [
            "  end tell",
            "  send newMessage",
            "end tell",
        ])
        return lines.joined(separator: "\n")
    }

    /// AppleScript string literal escaping: backslash first, then quotes.
    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: execution

    private static func run(_ source: String) -> Result<Void, SendError> {
        if let capture = dryRunCapture {
            capture(source)
            return .success(())
        }
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(.scriptFailed("Could not build automation script"))
        }
        script.executeAndReturnError(&error)
        if let error {
            let msg = (error[NSAppleScript.errorBriefMessage] as? String)
                ?? (error[NSAppleScript.errorMessage] as? String)
                ?? "Automation failed (check System Settings → Privacy → Automation)"
            return .failure(.scriptFailed(msg))
        }
        return .success(())
    }
}
