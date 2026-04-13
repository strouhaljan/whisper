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
                LabeledContent("Language") {
                    LanguagePicker(selected: $appState.languages)
                }
                Text(languageHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Get a key at console.groq.com/keys")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // ── Shortcuts ────────────────────────────────────
            Card {
                Label("Shortcuts", systemImage: "command")
            } content: {
                ForEach($appState.bindings) { $binding in
                    ShortcutRow(binding: $binding) {
                        if appState.bindings.count > 1 {
                            appState.bindings.removeAll { $0.id == binding.id }
                        }
                    }
                }
                Button {
                    appState.bindings.append(HotkeyBinding())
                } label: {
                    Label("Add shortcut", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

                Text("Press a key combo or hold and release modifiers. For fn alone, set \"Press 🌐 key to: Do Nothing\" in System Settings → Keyboard.")
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
        .frame(width: 420)
        .onAppear { loginItems.refresh() }
    }

    private var languageHint: String {
        switch appState.languages.count {
        case 0: return "Auto-detect — works well for longer clips."
        case 1: return "Whisper will expect \(SupportedLanguage.name(for: appState.languages[0]))."
        default: return "Multiple languages — auto-detect with narrowed scope."
        }
    }
}

// MARK: - Shortcut row

private struct ShortcutRow: View {
    @Binding var binding: HotkeyBinding
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HotkeyRecorderView(hotkey: $binding.hotkey)
            Picker("", selection: $binding.mode) {
                ForEach(HotkeyBinding.Mode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Card

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
