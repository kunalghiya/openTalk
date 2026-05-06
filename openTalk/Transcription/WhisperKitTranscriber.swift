import Foundation
import os
import WhisperKit

/// Thread-safe wrapper over a `WhisperKit` pipeline.
///
/// `pipeline` and `isReady` are mutated by `load()` (typically MainActor) and
/// read by `transcribe()` (a non-isolated `Task`) and `isReady` callers
/// (MainActor). All access goes through `state` so two-writer / one-reader
/// races on the raw fields can't happen.
final class WhisperKitTranscriber: Transcriber, @unchecked Sendable {
    private struct State {
        var pipeline: WhisperKit?
        var isReady: Bool = false
    }
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var isReady: Bool {
        state.withLock { $0.isReady }
    }

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
            if !modelExistsLocally {
                NSLog("openTalk: whisper model cache miss — downloading (path=\(modelFolder))")
            }

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
            state.withLock {
                $0.pipeline = kit
                $0.isReady = true
            }
        } catch {
            throw TranscriberError.underlying(error)
        }
    }

    func transcribe(samples: [Float]) async throws -> String {
        // Snapshot the pipeline reference under the lock; the await happens
        // outside it. If load() replaces the pipeline mid-flight, the in-flight
        // transcription completes against its captured pipeline, which is fine.
        let pipeline = state.withLock { $0.pipeline }
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
