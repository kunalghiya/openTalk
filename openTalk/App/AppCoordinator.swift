import AppKit
import SwiftUI

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    let onboardingVM: OnboardingViewModel
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
        self.hotkey = HotkeyManager()
        self.recorder = AudioRecorder()
        let trans = WhisperKitTranscriber()
        self.transcriber = trans
        self.paster = Paster(restoreDelayMs: { store.clipboardRestoreDelayMs })
        self.onboardingVM = OnboardingViewModel(
            transcriber: trans,
            modelName: { store.selectedModelName }
        )
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
        }
    }

    func presentOnboardingIfNeeded() {
        let needsOnboarding =
            PermissionsChecker.microphone() != .granted ||
            !PermissionsChecker.accessibilityTrusted() ||
            !transcriber.isReady
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
            NSLog("openTalk: hotkey pressed before model ready; ignoring")
            return
        }
        do {
            try recorder.start()
            isCapturing = true
            menuBar.isRecording = true
        } catch {
            NSLog("openTalk: recorder.start failed: \(error)")
        }
    }

    private func handleHotkeyRelease() {
        guard isCapturing else { return }
        let samples = recorder.stop()
        isCapturing = false
        menuBar.isRecording = false
        guard !samples.isEmpty else { return }

        Task { [transcriber, paster] in
            do {
                let text = try await transcriber.transcribe(samples: samples)
                guard !text.isEmpty else { return }
                await MainActor.run { paster.paste(text) }
            } catch {
                NSLog("openTalk: transcribe failed: \(error)")
            }
        }
    }

    private func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings))
            let win = NSWindow(contentViewController: host)
            win.title = "openTalk Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
