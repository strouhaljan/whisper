import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loginItems: LoginItemService

    var body: some View {
        VStack(spacing: 12) {
            // ── Transcription ────────────────────────────────
            Card {
                Label("Transcription", systemImage: "waveform")
            } content: {
                LabeledContent("API key") {
                    SecureField("", text: $appState.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Model") {
                    Picker("", selection: $appState.model) {
                        Text("Large v3 Turbo").tag("whisper-large-v3-turbo")
                        Text("Large v3").tag("whisper-large-v3")
                        Text("Distil v3 (English)").tag("distil-whisper-large-v3-en")
                    }
                    .labelsHidden()
                }
                Text("Get a key at console.groq.com/keys")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // ── Shortcut ─────────────────────────────────────
            Card {
                Label("Shortcut", systemImage: "command")
            } content: {
                LabeledContent("Push to talk") {
                    HotkeyRecorderView(hotkey: $appState.hotkey)
                }
                Text("Press a key combo (e.g. ⌥Space) or hold and release modifiers (e.g. ⌃⌥). For fn alone, first set \"Press 🌐 key to: Do Nothing\" in System Settings → Keyboard.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // ── General ──────────────────────────────────────
            Card {
                Label("General", systemImage: "gearshape")
            } content: {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItems.isEnabled },
                    set: { loginItems.setEnabled($0) }
                ))
                if let error = loginItems.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if loginItems.statusMessage.contains("Approval") {
                    Button("Open Login Items in System Settings") {
                        loginItems.openLoginItemsSettings()
                    }
                    .font(.caption)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear { loginItems.refresh() }
    }
}

/// A full-width card with a title row inside the box.
private struct Card<Title: View, Content: View>: View {
    @ViewBuilder let title: Title
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }
}
