import AppKit
import SwiftUI

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    let onboardingVM: OnboardingViewModel
    let settingsVM: SettingsViewModel
    private let menuBar: MenuBarController
    private let hotkey: HotkeyManager
    private let recorder: AudioRecorder
    private let transcriber: Transcriber
    private let paster: Paster

    private var isCapturing = false
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init() {
        let store = SettingsStore()
        self.settings = store
        self.menuBar = MenuBarController()
        self.hotkey = HotkeyManager(trigger: { store.pushToTalkTrigger.modifierFlags })
        self.recorder = AudioRecorder()
        let trans = WhisperKitTranscriber()
        self.transcriber = trans
        self.paster = Paster(restoreDelayMs: { store.clipboardRestoreDelayMs })
        self.onboardingVM = OnboardingViewModel(
            transcriber: trans,
            modelName: { store.selectedModelName },
            triggerLabel: { store.pushToTalkTrigger.displayName }
        )
        self.settingsVM = SettingsViewModel(settings: store, transcriber: trans)
    }

    func start() {
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.onOpenSetup = { [weak self] in self?.showOnboardingWindow() }
        hotkey.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkey.onRelease = { [weak self] in self?.handleHotkeyRelease() }

        Task { await loadModelOnce() }
    }

    private func loadModelOnce() async {
        do {
            try await transcriber.load(modelName: settings.selectedModelName) { _ in }
            onboardingVM.refresh()
        } catch {
            NSLog("openTalk: model load failed: \(error)")
            menuBar.flashError(notify: "Couldn't load Whisper model — open Setup to retry.")
        }
    }

    func presentOnboardingIfNeeded() {
        // We check the model on *disk* (synchronous) instead of
        // `transcriber.isReady` because load runs async and won't have
        // settled yet at applicationDidFinishLaunching time. So a fully
        // permissioned, cached install would otherwise see Setup pop up
        // every launch.
        let needsOnboarding =
            PermissionsChecker.microphone() != .granted ||
            !PermissionsChecker.accessibilityTrusted() ||
            !WhisperKitTranscriber.isModelDownloaded(modelName: settings.selectedModelName)
        if needsOnboarding {
            showOnboardingWindow()
        }
    }

    func showOnboardingWindow() {
        if onboardingWindow == nil {
            let host = NSHostingController(rootView: OnboardingView(vm: onboardingVM))
            let win = NSWindow(contentViewController: host)
            win.title = "openTalk Setup"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            onboardingWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Push-to-talk

    private func handleHotkeyPress() {
        guard !isCapturing else { return }
        guard transcriber.isReady else {
            // Common during launch while the model is still loading.
            // Soft state: brief icon flash, no notification.
            menuBar.flashError(notify: nil)
            return
        }
        do {
            try recorder.start()
            isCapturing = true
            menuBar.isRecording = true
        } catch {
            NSLog("openTalk: recorder.start failed: \(error)")
            menuBar.flashError(notify: "Couldn't access the microphone.")
        }
    }

    private func handleHotkeyRelease() {
        guard isCapturing else { return }
        let samples = recorder.stop()
        isCapturing = false
        menuBar.isRecording = false
        guard !samples.isEmpty else { return }

        Task { [transcriber, paster, menuBar] in
            do {
                let text = try await transcriber.transcribe(samples: samples)
                guard !text.isEmpty else { return }
                await MainActor.run {
                    if !Paster.accessibilityTrusted() {
                        menuBar.flashError(
                            notify: "openTalk needs Accessibility access to paste. Open Setup to grant it."
                        )
                        return
                    }
                    paster.paste(text)
                }
            } catch {
                NSLog("openTalk: transcribe failed: \(error)")
                await MainActor.run {
                    menuBar.flashError(notify: "Transcription failed.")
                }
            }
        }
    }

    private func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings, modelVM: settingsVM))
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "openTalk Settings"
            win.contentViewController = host
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 520, height: 480))
            win.center()
            settingsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
