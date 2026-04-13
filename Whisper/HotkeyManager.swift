import Cocoa
import Carbon.HIToolbox

/// Manages a global CGEvent tap that matches multiple hotkey bindings,
/// supporting both push-to-talk and toggle modes.
final class HotkeyManager {
    var bindings: [HotkeyBinding]
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCancel: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Active recording state.
    private var activeBinding: HotkeyBinding?
    private var toggleArmed = false  // toggle modifier-only: mods released, waiting for re-press
    private var needsFullRelease = false  // after cancel, block re-trigger until all mods released

    init(bindings: [HotkeyBinding]) {
        self.bindings = bindings
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

    // MARK: - Event dispatch

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if activeBinding != nil {
            return handleWhileRecording(type: type, event: event)
        } else {
            return handleWhileIdle(type: type, event: event)
        }
    }

    // MARK: - Idle → try to start recording

    private func handleWhileIdle(type: CGEventType, event: CGEvent) -> Bool {
        // After a cancel, wait for all modifiers to be released before accepting new triggers.
        if needsFullRelease {
            if type == .flagsChanged && noModifiersHeld(event.flags) {
                needsFullRelease = false
            }
            return false
        }

        for binding in bindings {
            if matchesPress(type: type, event: event, binding: binding) {
                activeBinding = binding
                toggleArmed = false
                DispatchQueue.main.async { self.onPress?() }
                return !binding.hotkey.isModifierOnly
            }
        }
        return false
    }

    // MARK: - Recording → check for release

    private func handleWhileRecording(type: CGEventType, event: CGEvent) -> Bool {
        guard let active = activeBinding else { return false }

        // If the current binding is modifier-only and a keyDown arrives that
        // matches a more specific (key combo) binding, upgrade to that binding
        // without interrupting the recording. This lets ⌃⌥ (push-to-talk)
        // coexist with ⌃⌥Space (toggle) — the Space keyDown promotes the
        // session to toggle mode seamlessly.
        if active.hotkey.isModifierOnly && type == .keyDown {
            for binding in bindings where binding.id != active.id {
                if matchesPress(type: type, event: event, binding: binding) {
                    activeBinding = binding
                    toggleArmed = false
                    return true  // consume the keyDown
                }
            }
        }

        switch active.mode {
        case .pushToTalk:
            return handlePushToTalkRelease(type: type, event: event, binding: active)
        case .toggle:
            return handleToggleRelease(type: type, event: event, binding: active)
        }
    }

    // MARK: - Push-to-talk release

    private func handlePushToTalkRelease(type: CGEventType, event: CGEvent, binding: HotkeyBinding) -> Bool {
        let hotkey = binding.hotkey

        if hotkey.isModifierOnly {
            guard type == .flagsChanged else {
                // Don't consume keystrokes during modifier-only recording.
                // The user may be building a longer shortcut (e.g. ⌃⌥⌘←).
                return false
            }
            if !modsMatch(event.flags, hotkey: hotkey) {
                release()
            } else if extraModifiersPresent(event.flags, beyond: hotkey) {
                // User added modifiers beyond the binding (e.g. ⌃⌥ → ⌃⌥⌘).
                // This isn't a dictation — cancel without transcribing.
                cancel()
            }
            return false
        } else {
            guard let requiredKey = hotkey.keyCode else { return false }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

            switch type {
            case .keyDown:
                if keyCode == requiredKey { return true }  // consume auto-repeat
            case .keyUp:
                if keyCode == requiredKey {
                    release()
                    return true
                }
            case .flagsChanged:
                if !modsMatch(event.flags, hotkey: hotkey) {
                    release()
                }
            default:
                break
            }
            return false
        }
    }

    // MARK: - Toggle release

    private func handleToggleRelease(type: CGEventType, event: CGEvent, binding: HotkeyBinding) -> Bool {
        let hotkey = binding.hotkey

        if hotkey.isModifierOnly {
            // State machine: recording → mods released (armed) → mods pressed again → stop.
            guard type == .flagsChanged else {
                return false  // don't consume keystrokes
            }
            if extraModifiersPresent(event.flags, beyond: hotkey) {
                cancel()
            } else {
                let held = modsMatch(event.flags, hotkey: hotkey)
                if !toggleArmed && !held {
                    toggleArmed = true
                } else if toggleArmed && held {
                    release()
                }
            }
            return false
        } else {
            // Key combo toggle: press to start, release key, press again to stop.
            // toggleArmed becomes true after the first keyUp, so auto-repeat
            // and the initial keyDown don't accidentally stop recording.
            guard let requiredKey = hotkey.keyCode else { return false }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

            switch type {
            case .keyDown:
                if keyCode == requiredKey {
                    if toggleArmed && modsMatch(event.flags, hotkey: hotkey) {
                        release()
                    }
                    return true  // consume initial press + auto-repeat
                }
            case .keyUp:
                if keyCode == requiredKey {
                    toggleArmed = true
                    return true
                }
            default:
                break
            }
            return false
        }
    }

    // MARK: - Helpers

    private func matchesPress(type: CGEventType, event: CGEvent, binding: HotkeyBinding) -> Bool {
        let hotkey = binding.hotkey
        if hotkey.isModifierOnly {
            return type == .flagsChanged && modsMatch(event.flags, hotkey: hotkey)
        } else {
            guard type == .keyDown, let requiredKey = hotkey.keyCode else { return false }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            return keyCode == requiredKey && modsMatch(event.flags, hotkey: hotkey)
        }
    }

    /// Returns true if the current flags contain modifiers beyond what the hotkey requires.
    private func extraModifiersPresent(_ cgFlags: CGEventFlags, beyond hotkey: Hotkey) -> Bool {
        let required = hotkey.modifiers
        let extras: [(NSEvent.ModifierFlags, CGEventFlags)] = [
            (.command,  .maskCommand),
            (.option,   .maskAlternate),
            (.control,  .maskControl),
            (.shift,    .maskShift),
            (.function, .maskSecondaryFn),
        ]
        for (nsMod, cgMod) in extras {
            if !required.contains(nsMod) && cgFlags.contains(cgMod) {
                return true
            }
        }
        return false
    }

    private func modsMatch(_ cgFlags: CGEventFlags, hotkey: Hotkey) -> Bool {
        let required = hotkey.modifiers
        if required.contains(.command)  && !cgFlags.contains(.maskCommand)     { return false }
        if required.contains(.option)   && !cgFlags.contains(.maskAlternate)   { return false }
        if required.contains(.control)  && !cgFlags.contains(.maskControl)     { return false }
        if required.contains(.shift)    && !cgFlags.contains(.maskShift)       { return false }
        if required.contains(.function) && !cgFlags.contains(.maskSecondaryFn) { return false }
        return true
    }

    private func release() {
        activeBinding = nil
        toggleArmed = false
        DispatchQueue.main.async { self.onRelease?() }
    }

    private func cancel() {
        activeBinding = nil
        toggleArmed = false
        needsFullRelease = true
        DispatchQueue.main.async { self.onCancel?() }
    }

    private func noModifiersHeld(_ cgFlags: CGEventFlags) -> Bool {
        !cgFlags.contains(.maskCommand) &&
        !cgFlags.contains(.maskAlternate) &&
        !cgFlags.contains(.maskControl) &&
        !cgFlags.contains(.maskShift) &&
        !cgFlags.contains(.maskSecondaryFn)
    }
}
