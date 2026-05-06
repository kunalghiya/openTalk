# openTalk

Push-to-talk on-device dictation for macOS, in your menu bar.

Hold ⌥Space (configurable), speak, release. Transcript is pasted at the cursor in any text field. On-device transcription via [WhisperKit](https://github.com/argmaxinc/WhisperKit).

## Build

```bash
brew install xcodegen
xcodegen generate
open openTalk.xcodeproj
```

Build & run in Xcode (⌘R). On first launch you'll be asked to grant Microphone access, Accessibility access (needed to synthesise ⌘V into the foreground app), and to download a Whisper model.

## Requirements

- macOS 14+
- Apple Silicon
- Xcode 15+
