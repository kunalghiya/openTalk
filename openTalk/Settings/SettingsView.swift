import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Push-to-talk") { Text("Hold ⌃ Control") }
                Text("Hold Control alone to record, release to transcribe + paste. Pressing Control with any other key (e.g. ⌃C, ⌃click) will not trigger recording.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Model") {
                Picker("Whisper model", selection: $settings.selectedModelName) {
                    ForEach(ModelManager.recommended, id: \.id) { m in
                        Text("\(m.label) (~\(m.approxSizeMB) MB)").tag(m.id)
                    }
                }
                Text("Changing the model takes effect on next launch, or click Setup… to redownload now.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { v in launchAtLogin = v; LaunchAtLogin.isEnabled = v }
                ))
                Slider(
                    value: Binding(
                        get: { Double(settings.clipboardRestoreDelayMs) },
                        set: { settings.clipboardRestoreDelayMs = Int($0) }
                    ),
                    in: 100...2000, step: 50
                ) {
                    Text("Clipboard restore delay")
                } minimumValueLabel: { Text("100 ms") } maximumValueLabel: { Text("2000 ms") }
                Text("\(settings.clipboardRestoreDelayMs) ms after paste, your previous clipboard is restored.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 480)
    }
}
