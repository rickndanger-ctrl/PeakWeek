import Foundation
import AVFoundation

/// On-device compression before upload: hardware HEVC 1080p first; if the
/// result is still huge, drop to 720p. A 45-second set lands ~15-30MB.
enum VideoCompressor {

    static let retryThreshold: Int64 = 60 * 1024 * 1024   // 60MB → re-export 720p
    /// Above this even 720p isn't worth attempting on gym signal — it would
    /// fail on every retry, forever, while the UI claims it's still sending.
    static let hardLimit: Int64 = 120 * 1024 * 1024
    /// A form check is seconds long. Anything past this is a recording someone
    /// forgot to stop.
    static let maxDuration: Double = 180

    static func compress(_ source: URL) async throws -> URL {
        let duration = try await AVURLAsset(url: source).load(.duration).seconds
        if duration.isFinite, duration > maxDuration {
            throw APIError(message: "That clip is \(Int(duration / 60)) min long. Trim it to the set itself (under 3 min) and try again.")
        }
        let first = try await export(source, preset: AVAssetExportPresetHEVC1920x1080)
        if size(of: first) > retryThreshold {
            let second = try await export(source, preset: AVAssetExportPreset1280x720)
            try? FileManager.default.removeItem(at: first)
            // The 720p pass used to be trusted blindly; a long clip sails past
            // it and then times out on every upload attempt.
            let finalSize = size(of: second)
            if finalSize > hardLimit {
                try? FileManager.default.removeItem(at: second)
                throw APIError(message: "That video is too big to send (\(finalSize / 1_048_576) MB). Try a shorter clip.")
            }
            return second
        }
        return first
    }

    private static func size(of url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private static func export(_ source: URL, preset: String) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw APIError(message: "This video can't be processed.")
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        if session.status != .completed {
            throw session.error ?? APIError(message: "Video processing failed.")
        }
        return out
    }
}
