import AppKit

@MainActor
final class AppCoordinator {
    let settings: SettingsStore
    private let menuBar: MenuBarController
    private let hotkey: HotkeyManager
    private let recorder: AudioRecorder
    private let transcriber: Transcriber
    private let paster: Paster

    private var isCapturing = false

    init() {
        let store = SettingsStore()
        self.settings = store
        self.menuBar = MenuBarController()
        self.hotkey = HotkeyManager()
        self.recorder = AudioRecorder()
        self.transcriber = WhisperKitTranscriber()
        self.paster = Paster(restoreDelayMs: { store.clipboardRestoreDelayMs })
    }

    func start() {
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        hotkey.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkey.onRelease = { [weak self] in self?.handleHotkeyRelease() }

        Task { await loadModelOnce() }
    }

    private func loadModelOnce() async {
        do {
            try await transcriber.load(modelName: settings.selectedModelName) { _ in }
        } catch {
            NSLog("openTalk: model load failed: \(error)")
        }
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
        NSApp.activate(ignoringOtherApps: true)
    }
}
