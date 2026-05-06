import SwiftUI

@main
struct OpenTalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings window is managed by AppCoordinator as an NSWindow; keep
        // a placeholder Scene so the App protocol is satisfied without
        // emitting "Please use SettingsLink" warnings on macOS 14+.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?
    private let coordinator = AppCoordinator()
    var coordinatorRef: AppCoordinator { coordinator }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        Notifications.setUp()
        coordinator.start()
        coordinator.presentOnboardingIfNeeded()
    }
}
