import Foundation
import AVFoundation

/// On-device compression before upload: hardware HEVC 1080p first; if the
/// result is still huge, drop to 720p. A 45-second set lands ~15-30MB.
enum VideoCompressor {

    static let retryThreshold: Int64 = 60 * 1024 * 1024   // 60MB → re-export 720p

    static func compress(_ source: URL) async throws -> URL {
        let first = try await export(source, preset: AVAssetExportPresetHEVC1920x1080)
        let size = (try? FileManager.default.attributesOfItem(atPath: first.path)[.size] as? Int64) ?? 0
        if size > retryThreshold {
            let second = try await export(source, preset: AVAssetExportPreset1280x720)
            try? FileManager.default.removeItem(at: first)
            return second
        }
        return first
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
