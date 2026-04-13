import SwiftUI
import AppKit

/// Captures the user's desired hotkey. Supports two styles automatically:
///
/// • **Key combo** — user presses modifier(s) + a non-modifier key
///   (e.g. ⌥Space). Captured on keyDown.
/// • **Modifier-only** — user holds modifier(s) then releases without
///   pressing another key (e.g. ⌃⌥, or just fn). Captured on release.
///
/// The recorder detects which style the user intended based on whether
/// a keyDown arrives while modifiers are held.
struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey
    @State private var isRecording = false
    @State private var monitors: [Any] = []
    @StateObject private var state = RecorderState()

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "Press shortcut…" : hotkey.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 140)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording
                              ? Color.accentColor.opacity(0.2)
                              : Color.secondary.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }

    private func toggle() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        isRecording = true
        state.reset()

        let allowedMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

        // 1. keyDown → key combo captured immediately.
        let keyMon = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let effective = flags.intersection(allowedMods)

            guard !effective.isEmpty else {
                NSSound.beep()
                return nil
            }

            hotkey = Hotkey(
                keyCode: event.keyCode,
                modifierFlagsRawValue: effective.rawValue,
                keyLabel: Hotkey.label(for: event)
            )
            stopRecording()
            return nil
        }

        // 2. flagsChanged → track modifiers; capture modifier-only on full release.
        let flagsMon = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let effective = flags.intersection(allowedMods)

            if !effective.isEmpty {
                // Only update peak when modifiers are being added (the new
                // set is a superset of the previous peak). Releasing a key
                // makes the set smaller, so the peak is preserved.
                if effective.isSuperset(of: state.peakModifiers) {
                    state.peakModifiers = effective
                }
            } else if !state.peakModifiers.isEmpty {
                // All modifiers released and no keyDown arrived → modifier-only.
                hotkey = Hotkey(
                    keyCode: nil,
                    modifierFlagsRawValue: state.peakModifiers.rawValue,
                    keyLabel: ""
                )
                stopRecording()
            }
            return event  // don't consume flagsChanged
        }

        monitors = [keyMon, flagsMon].compactMap { $0 }
    }

    private func stopRecording() {
        isRecording = false
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors = []
        state.reset()
    }
}

/// Reference-type storage so closures see the same mutable state.
private class RecorderState: ObservableObject {
    var peakModifiers: NSEvent.ModifierFlags = []

    func reset() {
        peakModifiers = []
    }
}
