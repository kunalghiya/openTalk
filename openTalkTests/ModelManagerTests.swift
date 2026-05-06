import XCTest
@testable import openTalk

final class ModelManagerTests: XCTestCase {
    func test_displayLabel_strips_openai_whisper_prefix() {
        XCTAssertEqual(ModelManager.displayLabel(for: "openai_whisper-tiny"), "Tiny")
        XCTAssertEqual(ModelManager.displayLabel(for: "openai_whisper-base"), "Base")
    }

    func test_displayLabel_renders_english_suffix_as_parenthetical() {
        XCTAssertEqual(ModelManager.displayLabel(for: "openai_whisper-base.en"), "Base (English)")
        XCTAssertEqual(ModelManager.displayLabel(for: "openai_whisper-large-v3.en"), "Large v3 (English)")
    }

    func test_displayLabel_preserves_version_markers() {
        XCTAssertEqual(ModelManager.displayLabel(for: "openai_whisper-large-v3-turbo"), "Large v3 Turbo")
    }

    func test_displayLabel_handles_distil_prefix() {
        XCTAssertEqual(ModelManager.displayLabel(for: "distil-whisper_distil-large-v3"), "Distil Large v3")
    }

    func test_sortedForDisplay_orders_by_size_then_english() {
        let input = [
            "openai_whisper-large-v3",
            "openai_whisper-tiny",
            "openai_whisper-base.en",
            "openai_whisper-tiny.en",
            "openai_whisper-base",
            "distil-whisper_distil-large-v3",
        ]
        let sorted = ModelManager.sortedForDisplay(input)
        // tiny non-en, tiny en, base non-en, base en, large non-en, then distil group last
        XCTAssertEqual(sorted, [
            "openai_whisper-tiny",
            "openai_whisper-tiny.en",
            "openai_whisper-base",
            "openai_whisper-base.en",
            "openai_whisper-large-v3",
            "distil-whisper_distil-large-v3",
        ])
    }
}
