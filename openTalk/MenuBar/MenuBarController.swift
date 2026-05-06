import AppKit

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private var errorRevertWorkItem: DispatchWorkItem?

    var isRecording: Bool = false {
        didSet { refreshIcon() }
    }

    var onOpenSettings: (() -> Void)?
    var onOpenSetup: (() -> Void)?
    var onQuit: (() -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.idleImage()
        statusItem.button?.image?.isTemplate = true
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let setup = NSMenuItem(title: "Setup…", action: #selector(setupAction), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit openTalk", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func openSettingsAction() { onOpenSettings?() }
    @objc private func setupAction() { onOpenSetup?() }
    @objc private func quitAction() { onQuit?() }

    /// Show a brief red error indicator in the menu bar. If `notify` is
    /// non-nil, also post a system notification with that body.
    /// Reverts to idle/recording state after ~1.5 s.
    func flashError(notify: String?) {
        statusItem.button?.image = Self.errorImage()
        statusItem.button?.image?.isTemplate = true

        errorRevertWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // refreshIcon picks up whatever the current isRecording state is —
            // if a new recording started during the flash window, the recording
            // image takes precedence.
            self.refreshIcon()
        }
        errorRevertWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)

        if let notify {
            Notifications.post(notify)
        }
    }

    private func refreshIcon() {
        statusItem.button?.image = isRecording ? Self.recordingImage() : Self.idleImage()
        statusItem.button?.image?.isTemplate = true
    }

    private static func idleImage() -> NSImage? {
        NSImage(systemSymbolName: "mic", accessibilityDescription: "openTalk idle")
    }

    private static func recordingImage() -> NSImage? {
        NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "openTalk recording")
    }

    private static func errorImage() -> NSImage? {
        NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "openTalk error")
    }
}
