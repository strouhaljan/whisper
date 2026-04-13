import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "groqApiKey") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "groqModel") }
    }
    @Published var languages: [String] {
        didSet { UserDefaults.standard.set(languages, forKey: "languages") }
    }
    @Published var bindings: [HotkeyBinding] {
        didSet {
            if let data = try? JSONEncoder().encode(bindings) {
                UserDefaults.standard.set(data, forKey: "hotkeyBindings")
            }
        }
    }
    @Published var status: Status = .idle
    @Published var level: Float = 0

    enum Status: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .recording: return "Recording…"
            case .transcribing: return "Transcribing…"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "groqApiKey") ?? ""
        self.model = UserDefaults.standard.string(forKey: "groqModel") ?? "whisper-large-v3-turbo"
        self.languages = UserDefaults.standard.stringArray(forKey: "languages") ?? []

        // Migrate from single hotkey to bindings array.
        if let data = UserDefaults.standard.data(forKey: "hotkeyBindings"),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            self.bindings = decoded
        } else if let data = UserDefaults.standard.data(forKey: "hotkey"),
                  let legacy = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.bindings = [HotkeyBinding(hotkey: legacy, mode: .pushToTalk)]
            UserDefaults.standard.removeObject(forKey: "hotkey")
        } else {
            self.bindings = HotkeyBinding.defaultBindings
        }
    }
}
