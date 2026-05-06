import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let dictation = Self(
        "dictation",
        default: .init(.space, modifiers: [.option])
    )
}

@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    init() {
        KeyboardShortcuts.onKeyDown(for: .dictation) { [weak self] in
            self?.onPress?()
        }
        KeyboardShortcuts.onKeyUp(for: .dictation) { [weak self] in
            self?.onRelease?()
        }
    }
}
