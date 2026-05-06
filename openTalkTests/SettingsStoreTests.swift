import XCTest
@testable import openTalk

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "openTalkTests-\(UUID().uuidString)")!
        store = SettingsStore(defaults: defaults)
    }

    func test_defaults_areReasonable() {
        XCTAssertEqual(store.selectedModelName, "openai_whisper-base.en")
        XCTAssertEqual(store.clipboardRestoreDelayMs, 200)
    }

    func test_setSelectedModel_persists() {
        store.selectedModelName = "openai_whisper-small.en"
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.selectedModelName, "openai_whisper-small.en")
    }

    func test_setClipboardRestoreDelay_clampedToReasonableRange() {
        store.clipboardRestoreDelayMs = 50
        XCTAssertEqual(store.clipboardRestoreDelayMs, 100, "should clamp to >=100ms")
        store.clipboardRestoreDelayMs = 5_000
        XCTAssertEqual(store.clipboardRestoreDelayMs, 2_000, "should clamp to <=2000ms")
    }
}
