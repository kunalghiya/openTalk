# openTalk

**A free, open-source, on-device alternative to [Wispr Flow](https://wisprflow.ai/) for macOS.**

Hold a key, talk, release — your words paste into whatever you're typing in. No subscription, no cloud, no audio ever leaves your Mac. Transcription runs locally via [WhisperKit](https://github.com/argmaxinc/WhisperKit) and Apple's Neural Engine.

| | openTalk | Wispr Flow |
|---|---|---|
| Cost | Free | Subscription |
| Where audio runs | On-device | Cloud |
| Source code | MIT-licensed, on GitHub | Closed |
| Hotkey | Hold any modifier (⌃/⌥/⌘/⇧) | Configurable |
| Works offline | Yes | No |

**Trade-off:** openTalk gives you raw Whisper output. Wispr Flow does AI cleanup (filler removal, punctuation polish, formatting). If you want the polish, pay them; if you want privacy, ownership, and zero cost, this is for you.

---

## Install

### 1. Download the DMG

Grab the latest `openTalk-x.y.z.dmg` from [**Releases**](../../releases/latest).

### 2. Open it past Gatekeeper

Until openTalk is shipping notarized builds, macOS will refuse to open the app on first launch with *"Apple could not verify…"*. That's expected for unsigned builds — pick whichever workaround you prefer:

- **Easiest:** in Finder, **right-click `openTalk.app` → Open**, then click **Open** in the dialog. Once accepted, all future launches just work.
- **Or:** System Settings → Privacy & Security → scroll to "openTalk was blocked" → click **Open Anyway**.
- **Or (Terminal):** `xattr -dr com.apple.quarantine /Applications/openTalk.app`

### 3. Drag `openTalk.app` to `/Applications`

Drag the app icon onto the `Applications` shortcut inside the mounted DMG.

### 4. Launch it

A microphone icon appears in your menu bar (top of the screen). The Setup window walks you through the three things openTalk needs:

1. **Microphone** — to hear you.
2. **Accessibility** — to paste the transcription into the foreground app.
3. **Whisper model** — about 145 MB for the default `base.en` model. Downloaded once into `~/Library/Application Support/openTalk/`.

### 5. Use it

Click into any text field. **Hold ⌃ Control**, speak, release. The transcript pastes at the cursor. Your previous clipboard is restored ~200 ms later.

Click the menu-bar icon for **Settings…** to:
- Change the push-to-talk modifier (Control / Option / Command / Shift)
- Switch to a larger or multilingual Whisper model
- Toggle launch-at-login
- Tune the clipboard restore delay

---

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 / M2 / M3 / M4)
- ~150 MB of disk for the default model. Larger models are available — up to ~1.5 GB for `large-v3`.

---

## Build from source

```bash
brew install xcodegen
git clone https://github.com/<your-username>/openTalk.git
cd openTalk
cp Local.xcconfig.example Local.xcconfig
# edit Local.xcconfig and set DEVELOPMENT_TEAM to your Apple Developer team ID
xcodegen generate
open openTalk.xcodeproj
```

Build & run with ⌘R. CLI build:

```bash
xcodebuild -project openTalk.xcodeproj -scheme openTalk \
  -configuration Debug -destination 'platform=macOS' \
  -allowProvisioningUpdates build
```

To build a redistributable DMG locally:

```bash
./Scripts/build-release.sh
```

That produces an ad-hoc-signed DMG in `build/`. To produce a notarized DMG, set `DEVELOPER_ID_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD` env vars first — see the script header for details.

---

## Why isn't openTalk sandboxed?

Synthesizing a `⌘V` into another app via `CGEvent.post(tap: .cghidEventTap)` is incompatible with the macOS app sandbox. Like Raycast, TextExpander, and similar utilities, openTalk runs unsandboxed and asks for Accessibility permission instead. The trade-off: you grant openTalk the ability to send synthetic keystrokes; it's the only way to paste reliably into arbitrary apps.

---

## Releasing (for maintainers)

Tag and push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The [release workflow](.github/workflows/release.yml) builds on a GitHub-hosted macOS runner and uploads the DMG to a GitHub Release. If repo secrets `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `DEVELOPER_ID_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD` are set, the workflow signs with Developer ID and notarizes — Gatekeeper-clean. Without those secrets it falls back to ad-hoc, and users hit the workaround above.

---

## License

[MIT](LICENSE). Use it however you want.

## Credits

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for the on-device transcription pipeline.
- OpenAI's [Whisper](https://github.com/openai/whisper) for the underlying speech-recognition model.
