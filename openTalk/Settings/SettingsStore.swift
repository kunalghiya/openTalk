import Foundation
import Observation

/// Modifier the user holds (alone) to start push-to-talk.
enum HotkeyTrigger: String, CaseIterable, Identifiable {
    case control, option, command, shift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .control: return "⌃ Control"
        case .option:  return "⌥ Option"
        case .command: return "⌘ Command"
        case .shift:   return "⇧ Shift"
        }
    }

    /// Optional caveat shown next to the picker — set on triggers that are
    /// likely to misfire in normal use.
    var caveat: String? {
        switch self {
        case .control: return nil
        case .option:  return nil
        case .command: return "Most macOS shortcuts use ⌘. You'll get false starts every time you tap ⌘ by itself."
        case .shift:   return "⇧ alone is held briefly when typing capitals — expect lots of tiny recordings."
        }
    }
}

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
        if defaults.object(forKey: Keys.pushToTalkTrigger) == nil {
            defaults.set(HotkeyTrigger.control.rawValue, forKey: Keys.pushToTalkTrigger)
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

    var pushToTalkTrigger: HotkeyTrigger {
        get {
            HotkeyTrigger(rawValue: defaults.string(forKey: Keys.pushToTalkTrigger) ?? "")
                ?? .control
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.pushToTalkTrigger) }
    }

    private enum Keys {
        static let selectedModel = "openTalk.selectedModelName"
        static let restoreDelay = "openTalk.clipboardRestoreDelayMs"
        static let pushToTalkTrigger = "openTalk.pushToTalkTrigger"
    }
}
