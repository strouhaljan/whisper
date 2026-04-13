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
        self.hotkeys = HotkeyManager(bindings: appState.bindings)
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
        hotkeys.onCancel = { [weak self] in self?.cancelRecording() }
        hotkeys.start()

        // Live-update bindings when the user edits them in Settings.
        appState.$bindings
            .dropFirst()
            .sink { [weak self] newBindings in
                self?.hotkeys.bindings = newBindings
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

    private func cancelRecording() {
        guard appState.status == .recording else { return }
        overlay.hide()
        if let url = recorder.stop() {
            try? FileManager.default.removeItem(at: url)
        }
        appState.status = .idle
    }

    private func endRecording() {
        guard appState.status == .recording else { return }
        guard let url = recorder.stop() else {
            appState.status = .idle
            overlay.hide()
            return
        }
        appState.status = .transcribing
        overlay.showTranscribing()

        let lang = appState.languages.count == 1 ? appState.languages.first : nil
        let service = TranscriptionService(apiKey: appState.apiKey, model: appState.model, language: lang)
        Task { [weak self] in
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let text = try await service.transcribe(fileURL: url)
                guard let self else { return }
                if !text.isEmpty {
                    PasteService.paste(text)
                }
                self.appState.status = .idle
                self.overlay.hide()
            } catch {
                guard let self else { return }
                self.appState.status = .error(error.localizedDescription)
                self.overlay.showError(error.localizedDescription)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self.overlay.hide()
                self.appState.status = .idle
            }
        }
    }
}
