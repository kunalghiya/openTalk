import Foundation
import WhisperKit

final class WhisperKitTranscriber: Transcriber, @unchecked Sendable {
    private var pipeline: WhisperKit?
    private(set) var isReady = false

    func load(modelName: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        do {
            let cacheBase = Self.modelCacheDirectory()
            let modelFolder = cacheBase
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(modelName)
                .path
            let modelExistsLocally = FileManager.default.fileExists(atPath: modelFolder)

            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: cacheBase,
                modelFolder: modelExistsLocally ? modelFolder : nil,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: true
            )
            progress(0.05)
            let kit = try await WhisperKit(config)
            progress(1.0)
            self.pipeline = kit
            self.isReady = true
        } catch {
            throw TranscriberError.underlying(error)
        }
    }

    func transcribe(samples: [Float]) async throws -> String {
        guard let pipeline else { throw TranscriberError.notLoaded }
        do {
            let results = try await pipeline.transcribe(audioArray: samples)
            return results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw TranscriberError.underlying(error)
        }
    }

    /// Stable, app-scoped cache that survives across builds. Avoids
    /// WhisperKit's default `~/Documents/huggingface/` which can interact
    /// poorly with macOS file-access prompts and Xcode's per-build sandboxes.
    private static func modelCacheDirectory() -> URL {
        let fm = FileManager.default
        let support = (try? fm.url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true))
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support")
        let dir = support.appendingPathComponent("openTalk", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
