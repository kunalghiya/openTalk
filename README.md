# openTalk

Push-to-talk on-device dictation for macOS, in your menu bar. Hold ⌥Space (configurable), speak, release. Transcript is pasted at the cursor in any text field via clipboard + synthetic ⌘V; the previous clipboard is restored ~200 ms later.

Transcription runs entirely on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — nothing leaves your Mac.

## Build from source

```bash
brew install xcodegen
git clone <repo-url>
cd openTalk
xcodegen generate
open openTalk.xcodeproj
```

Build & run with ⌘R.

## First launch

You'll be asked to grant three things:

1. **Microphone** — so we can hear you.
2. **Accessibility** — so we can post `⌘V` into whatever app is in front. Open System Settings → Privacy & Security → Accessibility, drag `openTalk.app` into the list, and toggle it on. Quit and relaunch openTalk after granting.
3. **Whisper model** — about 145 MB for `base.en` (the default). Downloaded once into `~/Documents/huggingface/`.

The Setup window walks you through these. Reopen it any time from the menu bar's "Setup…" item.

## Settings

Menu bar → **Settings…**. Customise the hotkey, swap the Whisper model, toggle launch-at-login, or tune the clipboard restore delay (100–2000 ms).

## Requirements

- macOS 14+
- Apple Silicon
- Xcode 15+ to build

## Why isn't openTalk sandboxed?

Synthesising a `⌘V` into another app via `CGEvent.post(tap: .cghidEventTap)` is incompatible with the macOS app sandbox. Like Raycast, TextExpander, and similar utilities, openTalk runs unsandboxed and asks for Accessibility permission instead.
