import XCTest
import AVFoundation
@testable import openTalk

final class AudioBufferConverterTests: XCTestCase {
    func test_downsample_48kStereo_to_16kMono_halvesAndAverages() throws {
        // 1 second of 48kHz stereo: left = 1.0, right = -1.0 → mono should be 0.0
        let inFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 48_000,
                                     channels: 2,
                                     interleaved: false)!
        let frames: AVAudioFrameCount = 48_000
        let buf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frames)!
        buf.frameLength = frames
        for i in 0..<Int(frames) {
            buf.floatChannelData![0][i] = 1.0
            buf.floatChannelData![1][i] = -1.0
        }
        let converter = try AudioBufferConverter(inputFormat: inFormat)
        let chunk = try converter.append(buf)
        let tail = try converter.flush()
        let out = chunk + tail
        XCTAssertEqual(out.count, 16_000, accuracy: 50)            // ~1s @ 16k
        XCTAssertLessThan(abs(out.reduce(0, +) / Float(out.count)), 0.01)
    }

    func test_pass_through_when_inputAlreadyMono16k() throws {
        // No downmix, no resample — should round-trip the samples verbatim.
        let fmt = AudioBufferConverter.targetFormat
        let frames: AVAudioFrameCount = 4_096
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
        buf.frameLength = frames
        for i in 0..<Int(frames) {
            buf.floatChannelData![0][i] = sin(Float(i) * 0.01)
        }
        let converter = try AudioBufferConverter(inputFormat: fmt)
        let out = try converter.append(buf) + (try converter.flush())
        XCTAssertEqual(out.count, Int(frames), accuracy: 8)
    }

    func test_downsample_4channel_quadraphonic_averagesAllChannels() throws {
        // Four-channel input where channel n holds the constant n - 1.5
        // (-1.5, -0.5, 0.5, 1.5). The mean is 0, so post-downmix the
        // resampled output should also average to ~0.
        guard let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Quadraphonic) else {
            XCTFail("could not build quadraphonic layout")
            return
        }
        let inFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            interleaved: false,
            channelLayout: layout
        )
        let frames: AVAudioFrameCount = 24_000
        let buf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: frames)!
        buf.frameLength = frames
        guard let channels = buf.floatChannelData else {
            XCTFail("buffer has no float channel data")
            return
        }
        for c in 0..<4 {
            let value = Float(c) - 1.5
            for i in 0..<Int(frames) {
                channels[c][i] = value
            }
        }
        let converter = try AudioBufferConverter(inputFormat: inFormat)
        let out = try converter.append(buf) + (try converter.flush())
        XCTAssertGreaterThan(out.count, 7_500)                        // ~0.5s @ 16k
        XCTAssertLessThan(abs(out.reduce(0, +) / Float(out.count)), 0.01)
    }
}
