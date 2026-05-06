import SwiftUI

@main
struct OpenTalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() } // replaced in Task 11
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
        coordinator.start()
        coordinator.presentOnboardingIfNeeded()
    }
}
