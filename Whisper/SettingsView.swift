import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loginItems: LoginItemService

    var body: some View {
        Form {
            Section("Groq API") {
                SecureField("API Key", text: $appState.apiKey)
                    .textFieldStyle(.roundedBorder)
                Picker("Model", selection: $appState.model) {
                    Text("whisper-large-v3-turbo").tag("whisper-large-v3-turbo")
                    Text("whisper-large-v3").tag("whisper-large-v3")
                    Text("distil-whisper-large-v3-en").tag("distil-whisper-large-v3-en")
                }
            }

            Section("Push-to-talk hotkey") {
                HStack {
                    Text("Shortcut")
                    Spacer()
                    HotkeyRecorderView(hotkey: $appState.hotkey)
                }
                Text("Click the field, then either press a key combo (e.g. ⌥Space) or just hold and release modifier keys (e.g. ⌃⌥). You can also use the fn key alone — set \"Press 🌐 key to: Do Nothing\" in System Settings → Keyboard first.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Input level") {
                LevelMeter(level: appState.level)
                    .frame(height: 10)
                Text(meterCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItems.isEnabled },
                    set: { loginItems.setEnabled($0) }
                ))
                Text(loginItems.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = loginItems.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                if loginItems.statusMessage.contains("Approval") {
                    Button("Open Login Items in System Settings") {
                        loginItems.openLoginItemsSettings()
                    }
                }
            }

            Section("Status") {
                Text(appState.status.label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { loginItems.refresh() }
    }

    private var meterCaption: String {
        switch appState.status {
        case .recording: return "Recording — speak now."
        case .transcribing: return "Transcribing…"
        default: return "Hold your hotkey to test the microphone."
        }
    }
}

/// Simple horizontal level meter with a color ramp.
private struct LevelMeter: View {
    let level: Float  // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color(for: level))
                    .frame(width: max(2, CGFloat(level) * geo.size.width))
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
    }

    private func color(for level: Float) -> Color {
        switch level {
        case ..<0.6:  return .green
        case ..<0.85: return .yellow
        default:      return .red
        }
    }
}
