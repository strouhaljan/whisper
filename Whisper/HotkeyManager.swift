import Cocoa
import Carbon.HIToolbox

/// Global push-to-talk via a CGEvent tap.
/// Matches a configurable Hotkey and consumes matching events so they
/// don't reach the frontmost app.
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
        // Ask for accessibility permission so we can observe and consume global key events.
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

                // The system may disable the tap if it takes too long. Re-enable.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if manager.handle(type: type, event: event) {
                    return nil  // consume
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            NSLog("Whisper: failed to create event tap. Grant Accessibility permission in System Settings → Privacy & Security → Accessibility, then relaunch.")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Returns true if the event matched the hotkey and should be consumed.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modsHeld = currentModifiersMatchRequired(event.flags)

        switch type {
        case .keyDown:
            if keyCode == hotkey.keyCode && modsHeld {
                if !isHeld {
                    isHeld = true
                    DispatchQueue.main.async { self.onPress?() }
                }
                return true  // consume initial press AND auto-repeats
            }

        case .keyUp:
            if keyCode == hotkey.keyCode && isHeld {
                isHeld = false
                DispatchQueue.main.async { self.onRelease?() }
                return true
            }

        case .flagsChanged:
            // User released a required modifier mid-recording — end the take.
            // Don't consume; the modifier key release is legitimate.
            if isHeld && !modsHeld {
                isHeld = false
                DispatchQueue.main.async { self.onRelease?() }
            }

        default:
            break
        }
        return false
    }

    private func currentModifiersMatchRequired(_ cgFlags: CGEventFlags) -> Bool {
        let required = hotkey.modifiers
        if required.contains(.command) && !cgFlags.contains(.maskCommand) { return false }
        if required.contains(.option)  && !cgFlags.contains(.maskAlternate) { return false }
        if required.contains(.control) && !cgFlags.contains(.maskControl) { return false }
        if required.contains(.shift)   && !cgFlags.contains(.maskShift) { return false }
        return true
    }
}
