import Foundation

protocol Transcriber: AnyObject, Sendable {
    /// Download (if needed) and load the named WhisperKit model. Reports progress in [0,1].
    func load(modelName: String, progress: @Sendable @escaping (Double) -> Void) async throws
    /// Transcribe 16 kHz mono Float32 samples into a text string.
    func transcribe(samples: [Float]) async throws -> String
    /// True once `load` has completed successfully.
    var isReady: Bool { get }
}

enum TranscriberError: Error {
    case notLoaded
    case underlying(Error)
}
