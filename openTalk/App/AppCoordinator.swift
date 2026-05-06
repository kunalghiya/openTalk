import AppKit

@MainActor
final class AppCoordinator {
    let settings: SettingsStore

    init() {
        self.settings = SettingsStore()
    }

    func start() {
        // Subsequent tasks attach: menu bar, hotkey manager, recorder, transcriber, paster.
    }
}
