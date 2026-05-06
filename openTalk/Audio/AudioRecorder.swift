import AVFoundation
import os

enum AudioRecorderError: Error {
    case engineFailed(Error)
    case converterFailed(Error)
}

@MainActor
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var converter: AudioBufferConverter?
    /// Lock-protected sample buffer. The audio tap thread appends synchronously;
    /// MainActor (via `stop()`) drains and clears under the same lock. This
    /// preserves sample ordering across buffers and prevents stop() from
    /// racing with in-flight enqueues — issues the prior `Task { @MainActor }`
    /// pattern silently exhibited.
    private let collected = OSAllocatedUnfairLock<[Float]>(initialState: [])
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }
        collected.withLock { $0.removeAll(keepingCapacity: true) }

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        let conv = try AudioBufferConverter(inputFormat: inFormat)
        self.converter = conv

        // Capture only the things we need into the audio-thread closure.
        // Avoiding `self` keeps the closure off MainActor isolation.
        let buffer = collected
        input.installTap(onBus: 0, bufferSize: 4_096, format: inFormat) { audioBuffer, _ in
            let chunk: [Float]
            do {
                chunk = try conv.append(audioBuffer)
            } catch {
                return
            }
            buffer.withLock { $0.append(contentsOf: chunk) }
        }

        engine.prepare()
        do { try engine.start() } catch { throw AudioRecorderError.engineFailed(error) }
        isRunning = true
    }

    func stop() -> [Float] {
        guard isRunning else { return [] }
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let tail = (try? converter?.flush()) ?? []
        // Atomic swap-out: any tap callback that was already in flight when
        // removeTap returned will have completed; nothing new can append.
        let result = collected.withLock { samples -> [Float] in
            let out = samples
            samples.removeAll(keepingCapacity: true)
            return out
        }
        converter = nil
        return result + tail
    }
}

// MARK: - AudioBufferConverter

/// Streams arbitrary-format input AVAudioPCMBuffers and yields 16 kHz mono Float32 samples.
/// Downmixes multi-channel input by averaging, then resamples to 16 kHz.
///
/// Marked `@unchecked Sendable` because access is serialized by callers:
/// during recording only the audio render thread calls `append()`, and
/// only after the tap is removed does MainActor call `flush()`.
final class AudioBufferConverter: @unchecked Sendable {
    static let targetSampleRate: Double = 16_000
    static let targetFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: AudioBufferConverter.targetSampleRate,
        channels: 1,
        interleaved: false
    )!

    private let converter: AVAudioConverter
    private let monoInputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) throws {
        guard let monoFmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.converterFailed(
                NSError(domain: "openTalk.AudioBufferConverter", code: 1)
            )
        }
        self.monoInputFormat = monoFmt
        guard let c = AVAudioConverter(from: monoFmt, to: Self.targetFormat) else {
            throw AudioRecorderError.converterFailed(
                NSError(domain: "openTalk.AudioBufferConverter", code: 2)
            )
        }
        self.converter = c
    }

    /// Convert a single input buffer; returns the slice produced *during* this call.
    @discardableResult
    func append(_ inBuffer: AVAudioPCMBuffer) throws -> [Float] {
        let monoBuffer = downmixToMono(inBuffer)
        // 2× expected output size to comfortably absorb filter delay and
        // any AVAudioConverter quirks where output briefly exceeds the
        // naive ratio-based estimate.
        let outFrames = AVAudioFrameCount(
            (Double(monoBuffer.frameLength) * Self.targetSampleRate / monoInputFormat.sampleRate) * 2 + 1024
        )
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: Self.targetFormat,
            frameCapacity: max(1024, outFrames)
        ) else {
            return []
        }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return monoBuffer
        }
        if status == .error, let error { throw AudioRecorderError.converterFailed(error) }
        return floats(from: outBuffer)
    }

    /// Drain remaining filter state on stop. Loops until the converter signals
    /// no more data, in case the tail spans more than one output buffer.
    func flush() throws -> [Float] {
        var all: [Float] = []
        for _ in 0..<8 {
            guard let outBuffer = AVAudioPCMBuffer(
                pcmFormat: Self.targetFormat,
                frameCapacity: 4_096
            ) else { break }
            var error: NSError?
            let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .endOfStream
                return nil
            }
            if status == .error, let error { throw AudioRecorderError.converterFailed(error) }
            let chunk = floats(from: outBuffer)
            if chunk.isEmpty { break }
            all.append(contentsOf: chunk)
            if outBuffer.frameLength < outBuffer.frameCapacity { break }
        }
        return all
    }

    private func downmixToMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        if buffer.format.channelCount == 1 {
            return buffer
        }
        guard let mb = AVAudioPCMBuffer(pcmFormat: monoInputFormat, frameCapacity: buffer.frameLength),
              let inChans = buffer.floatChannelData else {
            return buffer
        }
        mb.frameLength = buffer.frameLength
        let outPtr = mb.floatChannelData![0]
        let n = Int(buffer.frameLength)
        let chCount = Int(buffer.format.channelCount)
        let invChCount = 1.0 / Float(chCount)
        for i in 0..<n {
            var sum: Float = 0
            for c in 0..<chCount { sum += inChans[c][i] }
            outPtr[i] = sum * invChCount
        }
        return mb
    }

    private func floats(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let ptr = buffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: ptr, count: Int(buffer.frameLength)))
    }
}
