import SwiftUI
import AppKit

@MainActor
@Observable
final class OnboardingViewModel {
    var micStatus: PermissionsChecker.MicStatus = .notDetermined
    var accessibilityTrusted: Bool = false
    var modelDownloadProgress: Double = 0
    var modelLoaded: Bool = false
    var modelError: String?

    private let transcriber: Transcriber
    private let modelName: () -> String

    init(transcriber: Transcriber, modelName: @escaping () -> String) {
        self.transcriber = transcriber
        self.modelName = modelName
    }

    func refresh() {
        micStatus = PermissionsChecker.microphone()
        accessibilityTrusted = PermissionsChecker.accessibilityTrusted()
        modelLoaded = transcriber.isReady
    }

    func requestMic() async {
        _ = await PermissionsChecker.requestMicrophone()
        refresh()
    }

    func openAccessibility() {
        PermissionsChecker.openAccessibilitySettings()
    }

    func downloadModel() async {
        modelError = nil
        modelDownloadProgress = 0
        do {
            try await transcriber.load(modelName: modelName()) { [weak self] p in
                Task { @MainActor in self?.modelDownloadProgress = p }
            }
            refresh()
        } catch {
            modelError = String(describing: error)
        }
    }
}

struct OnboardingView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to openTalk")
                .font(.largeTitle).bold()
            Text("openTalk needs three things before it can dictate:")
                .foregroundStyle(.secondary)

            stepRow(title: "Microphone access",
                    done: vm.micStatus == .granted,
                    actionLabel: vm.micStatus == .denied ? "Open System Settings" : "Grant",
                    action: {
                        if vm.micStatus == .denied {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                        } else {
                            Task { await vm.requestMic() }
                        }
                    })

            stepRow(title: "Accessibility access (for paste)",
                    done: vm.accessibilityTrusted,
                    actionLabel: "Open System Settings",
                    action: { vm.openAccessibility() })

            VStack(alignment: .leading, spacing: 6) {
                stepRow(title: "Whisper model downloaded",
                        done: vm.modelLoaded,
                        actionLabel: "Download",
                        action: { Task { await vm.downloadModel() } })
                if !vm.modelLoaded && vm.modelDownloadProgress > 0 {
                    ProgressView(value: vm.modelDownloadProgress)
                }
                if let err = vm.modelError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Spacer()
            HStack {
                Button("Refresh") { vm.refresh() }
                Spacer()
                if vm.micStatus == .granted && vm.accessibilityTrusted && vm.modelLoaded {
                    Text("All set — hold ⌥Space to dictate.")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 360)
        .onAppear { vm.refresh() }
    }

    private func stepRow(title: String, done: Bool, actionLabel: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            Text(title)
            Spacer()
            if !done {
                Button(actionLabel, action: action)
            }
        }
    }
}
