import AppKit
import SwiftUI

@MainActor
@Observable
final class RecordingHUDState {
    enum Phase {
        case idle
        case recording
        case transcribing
    }
    var phase: Phase = .idle
}

/// Floating bottom-center HUD that surfaces while the user is dictating.
/// Click-through (`ignoresMouseEvents`), non-activating, visible across
/// Spaces and over fullscreen apps. The underlying SwiftUI view animates
/// its contents based on the shared state object.
@MainActor
final class RecordingHUDController {
    private let state = RecordingHUDState()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func setRecording() {
        hideWorkItem?.cancel()
        state.phase = .recording
        ensurePanel()
        repositionAtBottomCenter()
        panel?.orderFront(nil)
    }

    func setTranscribing() {
        state.phase = .transcribing
        ensurePanel()
        panel?.orderFront(nil)
    }

    /// Hide after a short delay so a successful paste reads as "transcribed →
    /// gone" instead of snapping shut the moment the keypress completes.
    func hideSoon(after seconds: Double = 0.35) {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    func hide() {
        state.phase = .idle
        panel?.orderOut(nil)
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let host = NSHostingController(rootView: RecordingHUDView(state: state))
        host.view.wantsLayer = true
        // Panel is intentionally larger than the visible capsule so the
        // capsule's drop shadow has room to render without being clipped
        // by the panel's edges. The SwiftUI frame below uses the same size.
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentViewController = host
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.isReleasedWhenClosed = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        panel = p
    }

    private func repositionAtBottomCenter() {
        guard let panel,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.minY + 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - View

struct RecordingHUDView: View {
    let state: RecordingHUDState

    var body: some View {
        HStack(spacing: 12) {
            indicator
                .frame(width: 30, height: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background {
            Capsule()
                .fill(.black.opacity(0.85))
                .overlay {
                    Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 10, y: 3)
        }
        // Outer frame matches the NSPanel's contentRect — must be larger
        // than the capsule itself so the drop shadow doesn't clip.
        .frame(width: 260, height: 88)
        .animation(.easeInOut(duration: 0.18), value: state.phase)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state.phase {
        case .recording:
            WaveformBars()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .idle:
            EmptyView()
        }
    }

    private var label: String {
        switch state.phase {
        case .recording:    return "Listening…"
        case .transcribing: return "Transcribing…"
        case .idle:         return ""
        }
    }
}

/// Five animated bars that bounce up and down on independent phases.
/// Cheap synthetic animation — does not reflect the actual mic level
/// (that would require plumbing RMS samples from AudioRecorder).
private struct WaveformBars: View {
    private let count = 5
    private let phaseOffsets: [Double] = [0, 0.6, 1.2, 1.9, 0.3]
    private let barColor = Color(red: 1.0, green: 0.32, blue: 0.32)

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { i in
                    let phase = phaseOffsets[i % phaseOffsets.count]
                    let h = 5 + 14 * abs(sin(t * 4.5 + phase))
                    Capsule()
                        .fill(barColor)
                        .frame(width: 3, height: h)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
