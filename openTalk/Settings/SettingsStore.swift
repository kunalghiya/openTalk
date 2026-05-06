import Foundation
import Observation

@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.selectedModel) == nil {
            defaults.set("openai_whisper-base.en", forKey: Keys.selectedModel)
        }
        if defaults.object(forKey: Keys.restoreDelay) == nil {
            defaults.set(200, forKey: Keys.restoreDelay)
        }
    }

    var selectedModelName: String {
        get { defaults.string(forKey: Keys.selectedModel) ?? "openai_whisper-base.en" }
        set { defaults.set(newValue, forKey: Keys.selectedModel) }
    }

    var clipboardRestoreDelayMs: Int {
        get { defaults.integer(forKey: Keys.restoreDelay) }
        set {
            let clamped = min(2_000, max(100, newValue))
            defaults.set(clamped, forKey: Keys.restoreDelay)
        }
    }

    private enum Keys {
        static let selectedModel = "openTalk.selectedModelName"
        static let restoreDelay = "openTalk.clipboardRestoreDelayMs"
    }
}
