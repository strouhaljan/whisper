# Whisper

macOS menu-bar app for push-to-talk voice dictation. Hold a hotkey, speak, release — transcribed text is pasted into the frontmost app.

## Quick start

```bash
./build.sh        # creates signing cert (first run), generates Xcode project, builds Release
open build/DerivedData/Build/Products/Release/Whisper.app
```

Requires: Xcode CLI tools, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

First launch: grant **Accessibility** and **Microphone** permissions when prompted. Add your Groq API key in Settings (⌘,).

## Architecture

```
WhisperApp          @main, MenuBarExtra scene, Settings scene
  AppDelegate       creates AppState + DictationCoordinator
    DictationCoordinator   orchestrates the pipeline:
      HotkeyManager        global CGEvent tap, push-to-talk & toggle state machines
      AudioRecorder         AVAudioEngine → .wav file, real-time FFT spectrum
        SpectrumAnalyzer    vDSP FFT, 16 log-spaced bands (80 Hz–4 kHz)
      TranscriptionService  multipart POST to Groq Whisper API
      PasteService          NSPasteboard + synthetic ⌘V via CGEvent
      RecordingOverlay      floating NSPanel tooltip (spectrum / spinner / error)
```

### Key data flow

1. `HotkeyManager` detects hotkey press → calls `DictationCoordinator.beginRecording()`
2. `AudioRecorder` captures audio via `AVAudioEngine`, streams FFT bands to overlay
3. On hotkey release → `recorder.stop()` returns temp .wav URL
4. `TranscriptionService.transcribe(fileURL:)` uploads to Groq, returns text
5. `PasteService.paste(_:)` puts text on pasteboard and synthesizes ⌘V

### Hotkey system

- Supports key combos (⌃⌥Space) and modifier-only triggers (⌃⌥, fn)
- Two modes per binding: **push-to-talk** (hold to record) and **toggle** (press to start, press again to stop)
- Modifier-only bindings can be promoted to key-combo bindings mid-recording (e.g. ⌃⌥ push-to-talk coexists with ⌃⌥Space toggle)
- Cancel logic: adding extra modifiers beyond the binding cancels without transcribing
- `needsFullRelease` prevents re-triggering until all modifiers are released after a cancel

### State persistence

All settings stored in `UserDefaults`: API key, model, language, hotkey bindings (JSON-encoded `[HotkeyBinding]`). Migration path from legacy single-hotkey format.

## Build & signing

The project uses **manual code signing** with a self-signed "Whisper Dev" certificate. `build.sh` creates this certificate on first run and reuses it across rebuilds — this keeps macOS Accessibility and Microphone grants stable (no re-granting after each build).

- `project.yml` → XcodeGen generates `Whisper.xcodeproj`
- `CODE_SIGN_STYLE: Manual`, `CODE_SIGN_IDENTITY: "Whisper Dev"`
- No sandbox (entitlements: audio-input + network.client)
- `LSUIElement: true` — no Dock icon

## Conventions

- Swift 5.9, macOS 14.0+ deployment target
- `@MainActor` on all UI-touching classes (`AppState`, `DictationCoordinator`, `RecordingOverlay`)
- `HotkeyManager` runs on the main run loop (CGEvent tap requirement) but is not `@MainActor` — callbacks dispatch to main via `DispatchQueue.main.async`
- No external dependencies — all Apple frameworks (AVFoundation, Accelerate, Carbon, SwiftUI, AppKit)

## Troubleshooting

- **Hotkey not working after rebuild**: remove app from System Settings → Privacy → Accessibility, relaunch (it will re-prompt). This should be rare with stable signing.
- **fn key alone**: requires "Press globe key to: Do Nothing" in System Settings → Keyboard.
- **Event tap disabled**: if macOS disables the tap (timeout), `HotkeyManager` automatically re-enables it.
