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
    @Published var hotkey: Hotkey {
        didSet {
            if let data = try? JSONEncoder().encode(hotkey) {
                UserDefaults.standard.set(data, forKey: "hotkey")
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
        if let data = UserDefaults.standard.data(forKey: "hotkey"),
           let decoded = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.hotkey = decoded
        } else {
            self.hotkey = .default
        }
    }
}
