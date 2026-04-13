import SwiftUI
import AppKit

/// A floating tooltip at bottom-center of the screen that shows:
/// - spectrum bars while recording
/// - a spinner while transcribing
/// - a red dot on error
/// Never steals focus, fully click-through.
@MainActor
final class RecordingOverlay {
    private var panel: NSPanel?
    private let viewModel = OverlayViewModel()

    func show() {
        viewModel.phase = .recording
        viewModel.spectrum = Array(repeating: 0, count: 16)
        viewModel.errorText = nil

        guard panel == nil else { return }

        let content = OverlayTooltip(vm: viewModel)
        let hosting = NSHostingView(rootView: content)
        let size = NSSize(width: 120, height: 28)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.ignoresMouseEvents = true

        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            let x = area.midX - size.width / 2
            let y = area.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func showTranscribing() {
        viewModel.phase = .transcribing
    }

    func showError(_ message: String) {
        viewModel.phase = .error
        viewModel.errorText = message
    }

    func updateSpectrum(_ bands: [Float]) {
        viewModel.spectrum = bands
    }
}

// MARK: - View model

@MainActor
final class OverlayViewModel: ObservableObject {
    enum Phase { case recording, transcribing, error }

    @Published var phase: Phase = .recording
    @Published var spectrum: [Float] = Array(repeating: 0, count: 16)
    @Published var errorText: String?
}

// MARK: - SwiftUI views

private struct OverlayTooltip: View {
    @ObservedObject var vm: OverlayViewModel

    var body: some View {
        Group {
            switch vm.phase {
            case .recording:
                spectrumBars
            case .transcribing:
                transcribingView
            case .error:
                errorView
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
        )
    }

    private var spectrumBars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(vm.spectrum.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.25 + Double(level) * 0.25))
                    .frame(width: 3, height: max(2, CGFloat(level) * 10))
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
        .frame(height: 10)
    }

    private var transcribingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
            Text("Transcribing")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(height: 10)
    }

    private var errorView: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
            Text("Failed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(height: 10)
    }
}
