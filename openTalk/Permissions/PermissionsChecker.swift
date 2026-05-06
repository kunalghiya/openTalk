import AppKit
import AVFoundation
import ApplicationServices

@MainActor
enum PermissionsChecker {
    enum MicStatus { case notDetermined, denied, granted }

    static func microphone() -> MicStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        case .authorized: return .granted
        @unknown default: return .denied
        }
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func accessibilityTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false as CFBoolean] as CFDictionary)
    }

    /// Trigger TCC to register *this exact running binary* in the Accessibility list
    /// (shows a system dialog with an "Open System Settings" button), then also
    /// fall back to opening the pane directly in case the user dismissed it.
    static func promptAndOpenAccessibilitySettings() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true as CFBoolean] as CFDictionary)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Path of the running app bundle — useful for diagnosing TCC mismatches.
    static var runningAppPath: String {
        Bundle.main.bundlePath
    }
}
