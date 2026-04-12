import Cocoa
import Carbon.HIToolbox

/// Writes text to the clipboard and synthesizes a ⌘V keystroke
/// so the text lands in whichever app currently has focus.
enum PasteService {
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay so the frontmost app definitely has focus
        // (we just released a hotkey, so the system is mid-event).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulateCmdV()
        }
    }

    private static func simulateCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
