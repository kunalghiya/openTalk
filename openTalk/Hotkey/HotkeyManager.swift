import AppKit

/// Push-to-talk via a single modifier key (currently Control). Watches
/// `NSEvent.flagsChanged` globally and locally so we hear it whether or
/// not openTalk is the active app. Global monitoring requires Accessibility
/// permission — the same permission we need for paste.
@MainActor
final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    /// The modifier that triggers push-to-talk. Hold to record, release to stop.
    private let trigger: NSEvent.ModifierFlags = .control

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isPressed = false

    init() {
        let handle: (NSEvent) -> Void = { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .flagsChanged,
            handler: handle
        )
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .flagsChanged
        ) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyTrigger = flags == trigger

        if !isPressed && onlyTrigger {
            isPressed = true
            onPress?()
        } else if isPressed && !onlyTrigger {
            // Either the trigger was released, or another modifier was added —
            // stop recording in both cases so we don't transcribe ⌃-shortcut chords.
            isPressed = false
            onRelease?()
        }
    }
}
