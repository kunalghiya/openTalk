import AppKit

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    private let menuBar: MenuBarController
    private let hotkey: HotkeyManager

    init() {
        self.settings = SettingsStore()
        self.menuBar = MenuBarController()
        self.hotkey = HotkeyManager()
    }

    func start() {
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        hotkey.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkey.onRelease = { [weak self] in self?.handleHotkeyRelease() }
    }

    private func handleHotkeyPress() {
        menuBar.isRecording = true
    }

    private func handleHotkeyRelease() {
        menuBar.isRecording = false
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
