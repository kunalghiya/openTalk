import Foundation
import UserNotifications

/// Best-effort user notifications. If the user denies authorization the
/// post() calls silently no-op; the menu-bar icon flash is the always-on
/// fallback feedback channel.
@MainActor
enum Notifications {
    private static let presenter = ForegroundPresenter()

    static func setUp() {
        UNUserNotificationCenter.current().delegate = presenter
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("openTalk: notification authorization failed: \(error)")
            }
        }
    }

    static func post(_ body: String, title: String = "openTalk") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("openTalk: notification post failed: \(error)")
            }
        }
    }
}

/// Forces banners to show even when openTalk has a window in the foreground
/// (e.g. the user is on the Setup window when the model load fails).
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
