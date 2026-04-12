import SwiftUI
import AppKit

/// A minimal floating spectrum visualizer at bottom-center of the screen.
/// Never steals focus, fully click-through.
@MainActor
final class RecordingOverlay {
    private var panel: NSPanel?
    private let viewModel = SpectrumViewModel()

    func show() {
        guard panel == nil else { return }

        let content = SpectrumTooltip(vm: viewModel)
        let hosting = NSHostingView(rootView: content)
        let size = NSSize(width: 100, height: 22)
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

    func updateSpectrum(_ bands: [Float]) {
        viewModel.spectrum = bands
    }
}

// MARK: - View model

@MainActor
final class SpectrumViewModel: ObservableObject {
    @Published var spectrum: [Float] = Array(repeating: 0, count: 16)
}

// MARK: - SwiftUI views

private struct SpectrumTooltip: View {
    @ObservedObject var vm: SpectrumViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(vm.spectrum.enumerated()), id: \.offset) { _, level in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.25 + Double(level) * 0.25))
                    .frame(width: 3, height: max(2, CGFloat(level) * 10))
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.45))
        )
    }
}
