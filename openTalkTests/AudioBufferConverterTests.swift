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
}
