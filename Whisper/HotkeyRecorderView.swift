import SwiftUI
import AppKit

/// A button that captures the next keystroke and writes it into the binding.
/// Rejects keystrokes that don't include at least one modifier, so the user
/// can't accidentally bind "A" and consume every A they type.
struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "Press a key combo…" : hotkey.displayString)
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let allowedMods: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            let effective = flags.intersection(allowedMods)

            // Require at least one modifier so we don't bind a bare letter key.
            guard !effective.isEmpty else {
                NSSound.beep()
                return nil  // swallow so the beep isn't a literal character
            }

            hotkey = Hotkey(
                keyCode: event.keyCode,
                modifierFlagsRawValue: effective.rawValue,
                keyLabel: Hotkey.label(for: event)
            )
            stopRecording()
            return nil  // consume — don't let the captured keystroke leak into the field
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
