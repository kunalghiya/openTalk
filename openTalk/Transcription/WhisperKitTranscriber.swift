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

    /// Cheap, synchronous check: is the model already on disk for the given name?
    /// Use this to decide whether onboarding is needed before triggering an
    /// async load — no need to wait for `isReady` to settle.
    static func isModelDownloaded(modelName: String) -> Bool {
        FileManager.default.fileExists(atPath: modelDirectory(for: modelName).path)
    }

    /// All models available from the WhisperKit HuggingFace repo.
    /// Network call; cache the result in your view model — don't refetch
    /// on every Settings open.
    static func fetchAvailableModelNames() async throws -> [String] {
        try await WhisperKit.fetchAvailableModels()
    }

    private static func modelDirectory(for modelName: String) -> URL {
        modelCacheDirectory()
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(modelName)
    }

    func load(modelName: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        let cacheBase = Self.modelCacheDirectory()
        let modelFolderURL = Self.modelDirectory(for: modelName)
        let modelExistsLocally = Self.isModelDownloaded(modelName: modelName)

        progress(0.01)

        // 0.0 .. 0.9 is the download phase. We split here so that even when the
        // download is a no-op (cache hit) we still show motion via the load
        // phase below.
        let resolvedFolderPath: String
        if modelExistsLocally {
            resolvedFolderPath = modelFolderURL.path
        } else {
            NSLog("openTalk: whisper model cache miss — downloading \(modelName)")
            do {
                let downloaded = try await WhisperKit.download(
                    variant: modelName,
                    downloadBase: cacheBase,
                    progressCallback: { p in
                        // p.fractionCompleted is 0.0 ... 1.0 across the download.
                        progress(min(0.9, p.fractionCompleted * 0.9))
                    }
                )
                resolvedFolderPath = downloaded.path
            } catch {
                throw TranscriberError.underlying(error)
            }
        }

        progress(0.9)

        // Now build the pipeline against the on-disk model. download:false so
        // WhisperKit doesn't redo what we just did.
        do {
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: cacheBase,
                modelFolder: resolvedFolderPath,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
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
