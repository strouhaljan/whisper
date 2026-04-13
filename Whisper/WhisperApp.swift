import SwiftUI

@main
struct WhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarIcon(appState: appDelegate.appState)
        }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
                .environmentObject(appDelegate.loginItems)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let loginItems = LoginItemService()
    private var coordinator: DictationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator = DictationCoordinator(appState: appState)
        coordinator?.start()
    }
}

private struct MenuBarIcon: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Image(systemName: symbolName)
    }

    private var symbolName: String {
        switch appState.status {
        case .idle:         return "mic.circle"
        case .recording:    return "mic.circle.fill"
        case .transcribing: return "waveform.circle"
        case .error:        return "exclamationmark.circle"
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text(appState.status.label)
        Divider()
        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Whisper") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
