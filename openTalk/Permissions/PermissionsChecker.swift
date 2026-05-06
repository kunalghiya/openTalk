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
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
