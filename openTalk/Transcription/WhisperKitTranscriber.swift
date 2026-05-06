import Foundation
import WhisperKit

final class WhisperKitTranscriber: Transcriber, @unchecked Sendable {
    private var pipeline: WhisperKit?
    private(set) var isReady = false

    func load(modelName: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        do {
            let config = WhisperKitConfig(
                model: modelName,
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
}
