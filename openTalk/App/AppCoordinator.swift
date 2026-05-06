import AppKit

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    private let menuBar: MenuBarController

    init() {
        self.settings = SettingsStore()
        self.menuBar = MenuBarController()
    }

    func start() {
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Replaced in Task 11 with real settings window.
    }
}
