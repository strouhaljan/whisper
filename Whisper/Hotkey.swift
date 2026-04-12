import AppKit
import Carbon.HIToolbox

/// A push-to-talk hotkey: a non-modifier key plus one or more modifier flags.
struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlagsRawValue: UInt
    var keyLabel: String

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue)
    }

    var displayString: String {
        var s = ""
        let m = modifiers
        if m.contains(.control) { s += "⌃" }
        if m.contains(.option)  { s += "⌥" }
        if m.contains(.shift)   { s += "⇧" }
        if m.contains(.command) { s += "⌘" }
        s += keyLabel
        return s
    }

    static let `default` = Hotkey(
        keyCode: UInt16(kVK_Space),
        modifierFlagsRawValue: NSEvent.ModifierFlags.option.rawValue,
        keyLabel: "Space"
    )

    /// Produces a human-readable label for the key portion of an NSEvent.
    static func label(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:        return "Space"
        case kVK_Return:       return "Return"
        case kVK_Escape:       return "Esc"
        case kVK_Tab:          return "Tab"
        case kVK_Delete:       return "⌫"
        case kVK_ForwardDelete:return "⌦"
        case kVK_LeftArrow:    return "←"
        case kVK_RightArrow:   return "→"
        case kVK_UpArrow:      return "↑"
        case kVK_DownArrow:    return "↓"
        case kVK_Home:         return "↖"
        case kVK_End:          return "↘"
        case kVK_PageUp:       return "⇞"
        case kVK_PageDown:     return "⇟"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            let chars = event.charactersIgnoringModifiers ?? ""
            return chars.isEmpty ? "Key \(event.keyCode)" : chars.uppercased()
        }
    }
}
