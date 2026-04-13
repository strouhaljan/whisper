import Cocoa
import Carbon.HIToolbox

/// Global push-to-talk via a CGEvent tap.
/// Supports both key combos (modifier + key) and modifier-only triggers
/// (e.g. hold ⌃⌥, or hold fn).
final class HotkeyManager {
    var hotkey: Hotkey
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    func start() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if manager.handle(type: type, event: event) {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if hotkey.isModifierOnly {
            return handleModifierOnly(type: type, event: event)
        } else {
            return handleKeyCombo(type: type, event: event)
        }
    }

    // MARK: - Modifier-only mode (e.g. ⌃⌥, fn)

    private func handleModifierOnly(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .flagsChanged else {
            if isHeld && (type == .keyDown || type == .keyUp) { return true }
            return false
        }

        let modsHeld = currentModifiersMatchRequired(event.flags)

        if modsHeld && !isHeld {
            isHeld = true
            DispatchQueue.main.async { self.onPress?() }
        } else if !modsHeld && isHeld {
            isHeld = false
            DispatchQueue.main.async { self.onRelease?() }
        }
        return false
    }

    // MARK: - Key combo mode (e.g. ⌥Space)

    private func handleKeyCombo(type: CGEventType, event: CGEvent) -> Bool {
        guard let requiredKey = hotkey.keyCode else { return false }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modsHeld = currentModifiersMatchRequired(event.flags)

        switch type {
        case .keyDown:
            if keyCode == requiredKey && modsHeld {
                if !isHeld {
                    isHeld = true
                    DispatchQueue.main.async { self.onPress?() }
                }
                return true
            }

        case .keyUp:
            if keyCode == requiredKey && isHeld {
                isHeld = false
                DispatchQueue.main.async { self.onRelease?() }
                return true
            }

        case .flagsChanged:
            if isHeld && !modsHeld {
                isHeld = false
                DispatchQueue.main.async { self.onRelease?() }
            }

        default:
            break
        }
        return false
    }

    // MARK: - Helpers

    private func currentModifiersMatchRequired(_ cgFlags: CGEventFlags) -> Bool {
        let required = hotkey.modifiers
        if required.contains(.command)  && !cgFlags.contains(.maskCommand)     { return false }
        if required.contains(.option)   && !cgFlags.contains(.maskAlternate)   { return false }
        if required.contains(.control)  && !cgFlags.contains(.maskControl)     { return false }
        if required.contains(.shift)    && !cgFlags.contains(.maskShift)       { return false }
        if required.contains(.function) && !cgFlags.contains(.maskSecondaryFn) { return false }
        return true
    }
}
