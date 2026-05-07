# openTalk

Push-to-talk on-device dictation for macOS, in your menu bar.

Hold a modifier key (default ⌃ Control), speak, release. The transcript pastes at the cursor in any text field via clipboard + synthetic ⌘V; your previous clipboard is restored ~200 ms later.

Transcription runs entirely on-device using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — nothing leaves your Mac.

## Requirements

- macOS 14+
- Apple Silicon
- ~150 MB of disk for the default `base.en` Whisper model (other models available, up to ~1.5 GB)

## Install

### From a release DMG

1. Download the latest `.dmg` from [Releases](../../releases/latest).
2. Open the DMG, drag `openTalk.app` into `Applications`.
3. Launch it. The menu-bar icon appears (a microphone). The Setup window walks you through the three things openTalk needs:
   - **Microphone** — to hear you.
   - **Accessibility** — to paste the transcription into the foreground app.
   - **Whisper model** — downloaded once into `~/Library/Application Support/openTalk/`.

> **If the build is unsigned/non-notarized** (no Apple Developer Program enrollment yet), macOS Gatekeeper will block first launch with "Apple could not verify openTalk." Workarounds:
> - **Right-click → Open** in Finder, then click "Open" in the dialog. Once accepted, future launches just work.
> - Or: `xattr -dr com.apple.quarantine /Applications/openTalk.app` in Terminal.
> - Or: System Settings → Privacy & Security → scroll to the "openTalk was blocked" line → "Open Anyway".

### From source

```bash
brew install xcodegen
git clone <this-repo>
cd openTalk
cp Local.xcconfig.example Local.xcconfig
# Edit Local.xcconfig and set DEVELOPMENT_TEAM to your Apple Developer team ID.
xcodegen generate
open openTalk.xcodeproj
```

Build & run with ⌘R.

For CLI builds:

```bash
xcodebuild -project openTalk.xcodeproj -scheme openTalk \
  -configuration Debug -destination 'platform=macOS' \
  -allowProvisioningUpdates build
```

`-allowProvisioningUpdates` lets `xcodebuild` create/refresh the macOS development provisioning profile automatically.

## Usage

Hold the push-to-talk modifier (default ⌃ Control), speak, release. Click the menu-bar icon for **Setup…** (re-run permission flow / re-download model) and **Settings…** (change hotkey, switch Whisper model, toggle launch-at-login, tune clipboard restore delay).

The hotkey can be Control / Option / Command / Shift. Models can be switched live in Settings — picking a model that isn't on disk triggers a download with progress shown in-place.

## Why isn't openTalk sandboxed?

Synthesising a `⌘V` into another app via `CGEvent.post(tap: .cghidEventTap)` is incompatible with the macOS app sandbox. Like Raycast, TextExpander, and similar utilities, openTalk runs unsandboxed and asks for Accessibility permission instead.

## Releasing (maintainers)

Tag a commit with `vX.Y.Z` and push the tag. The [release workflow](.github/workflows/release.yml) builds the DMG on a GitHub-hosted macOS runner and uploads it to a GitHub Release.

If repo secrets `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `DEVELOPER_ID_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` are set, the workflow signs with Developer ID and notarizes — Gatekeeper-clean. If those secrets are absent it falls back to ad-hoc signing — works, but users hit the workaround flow above.

To build a DMG locally:

```bash
./Scripts/build-release.sh
# add notarization env vars to produce a notarized DMG; see the script header
```

## License

[MIT](LICENSE).
