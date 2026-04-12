import Foundation
import ServiceManagement
import AppKit

/// Wraps SMAppService.mainApp so the Settings UI can toggle
/// "Launch at login" without touching legacy launchd plists.
@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled)
        statusMessage = Self.describe(status)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// Opens System Settings → General → Login Items so the user can
    /// approve the app if macOS is holding the registration in
    /// `.requiresApproval`.
    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered:
            return "Not set to launch at login."
        case .enabled:
            return "Whisper will start automatically when you log in."
        case .requiresApproval:
            return "Approval required — open System Settings → General → Login Items and enable Whisper."
        case .notFound:
            return "App not found. Move Whisper.app into /Applications and relaunch it from there."
        @unknown default:
            return "Unknown login-item status."
        }
    }
}
