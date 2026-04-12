# Whisper

A tiny macOS menu-bar app for push-to-talk voice dictation, powered by Groq's Whisper API.

## How it works

1. Hold **⌥ Option + Space** anywhere in macOS.
2. Speak while you hold the keys.
3. Release — the recording is sent to Groq Whisper, the result is copied to the clipboard, and ⌘V is synthesized into the frontmost app.

## Build

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```sh
brew install xcodegen
xcodegen generate
open Whisper.xcodeproj
```

Then in Xcode:

1. Select the **Whisper** target → Signing & Capabilities → set your Team (or leave as "Sign to Run Locally").
2. Build & Run (⌘R).

## First-run permissions

macOS will prompt for two permissions:

- **Microphone** — required to record your voice.
- **Accessibility** — required for the global hotkey and to synthesize the ⌘V paste keystroke. Grant in *System Settings → Privacy & Security → Accessibility*, then relaunch the app.

## Configuration

Open the menu-bar icon → **Settings…**

- Paste your **Groq API key** (get one at <https://console.groq.com/keys>).
- Pick a model. `whisper-large-v3-turbo` is the fastest; `whisper-large-v3` is the most accurate.

## File layout

```
Whisper/
├── WhisperApp.swift           # @main, NSApplicationDelegate, status bar item
├── AppState.swift             # Settings + status state (ObservableObject)
├── SettingsView.swift         # SwiftUI Settings window
├── DictationCoordinator.swift # Glue: hotkey → record → transcribe → paste
├── HotkeyManager.swift        # Global push-to-talk via CGEvent tap
├── AudioRecorder.swift        # AVAudioRecorder → temp .m4a
├── TranscriptionService.swift # POST multipart to Groq Whisper
├── PasteService.swift         # NSPasteboard + synthesized ⌘V
└── Resources/
    ├── Info.plist
    └── Whisper.entitlements
```
