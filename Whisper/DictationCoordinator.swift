import Foundation
import Combine

/// Glue: hotkey → record → transcribe → paste.
@MainActor
final class DictationCoordinator {
    private let appState: AppState
    private let hotkeys: HotkeyManager
    private let recorder = AudioRecorder()
    private let overlay = RecordingOverlay()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.hotkeys = HotkeyManager(hotkey: appState.hotkey)
    }

    func start() {
        Task {
            _ = await recorder.requestPermission()
        }

        recorder.onSpectrum = { [weak self] bands in
            Task { @MainActor in
                guard let self else { return }
                self.overlay.updateSpectrum(bands)
                self.appState.level = bands.max() ?? 0
            }
        }

        hotkeys.onPress = { [weak self] in self?.beginRecording() }
        hotkeys.onRelease = { [weak self] in self?.endRecording() }
        hotkeys.start()

        // Live-update the hotkey when the user changes it in Settings.
        appState.$hotkey
            .dropFirst()
            .sink { [weak self] newHotkey in
                self?.hotkeys.hotkey = newHotkey
            }
            .store(in: &cancellables)
    }

    private func beginRecording() {
        guard appState.status == .idle else { return }
        do {
            try recorder.start()
            appState.status = .recording
            overlay.show()
        } catch {
            appState.status = .error(error.localizedDescription)
        }
    }

    private func endRecording() {
        guard appState.status == .recording else { return }
        overlay.hide()
        guard let url = recorder.stop() else {
            appState.status = .idle
            return
        }
        appState.status = .transcribing

        let service = TranscriptionService(apiKey: appState.apiKey, model: appState.model)
        Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let text = try await service.transcribe(fileURL: url)
                guard let self else { return }
                if !text.isEmpty {
                    PasteService.paste(text)
                }
                self.appState.status = .idle
            } catch {
                self?.appState.status = .error(error.localizedDescription)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.appState.status = .idle
            }
        }
    }
}
