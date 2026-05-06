import Foundation
import Observation

/// Drives the Settings window's model picker.
///
/// - Lazily fetches the full list of WhisperKit models on first appear.
/// - When the user picks a different model, kicks off a (potentially
///   downloading) `transcriber.load(...)` and surfaces progress.
/// - On success, the live `transcriber` is now backed by the new model;
///   no relaunch needed.
@MainActor
@Observable
final class SettingsViewModel {
    var availableModels: [String] = ModelManager.fallbackModelNames
    var fetchingModels: Bool = false
    /// 0.0 .. 1.0 while a model is loading or downloading. nil when idle.
    var modelProgress: Double? = nil
    var modelError: String? = nil

    private let settings: SettingsStore
    private let transcriber: Transcriber
    private var loadTask: Task<Void, Never>?

    init(settings: SettingsStore, transcriber: Transcriber) {
        self.settings = settings
        self.transcriber = transcriber
    }

    var selectedModelName: String {
        get { settings.selectedModelName }
        set {
            guard newValue != settings.selectedModelName else { return }
            settings.selectedModelName = newValue
            startApplyingModelChange(newValue)
        }
    }

    /// Pull the full list from HuggingFace. No-op if we already fetched.
    func loadAvailableModelsIfNeeded() async {
        guard !fetchingModels,
              availableModels == ModelManager.fallbackModelNames else { return }
        fetchingModels = true
        defer { fetchingModels = false }
        do {
            let names = try await WhisperKitTranscriber.fetchAvailableModelNames()
            // Make sure the currently selected model is in the list even if
            // the upstream removed it (or fetch returned a smaller subset).
            var unique = Set(names)
            unique.insert(settings.selectedModelName)
            availableModels = ModelManager.sortedForDisplay(Array(unique))
        } catch {
            NSLog("openTalk: fetchAvailableModels failed: \(error)")
        }
    }

    private func startApplyingModelChange(_ name: String) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.applyModelChange(name)
        }
    }

    private func applyModelChange(_ name: String) async {
        modelError = nil
        // Pre-set progress to a tiny value so the UI shows the bar immediately
        // for the download-needed case. For cache-hit, it'll snap to nil quickly.
        modelProgress = WhisperKitTranscriber.isModelDownloaded(modelName: name) ? 0.95 : 0.0
        do {
            try await transcriber.load(modelName: name) { [weak self] p in
                Task { @MainActor in
                    guard let self else { return }
                    self.modelProgress = p < 1.0 ? p : nil
                }
            }
            modelProgress = nil
        } catch {
            modelError = error.localizedDescription
            modelProgress = nil
        }
    }
}
