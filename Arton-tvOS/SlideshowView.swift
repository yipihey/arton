import SwiftUI
import ArtonCore

/// Full-screen slideshow view for tvOS
/// Displays artwork images with Siri Remote control support
struct SlideshowView: View {
    let gallery: Gallery

    @StateObject private var displaySettingsManager = DisplaySettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SlideshowViewCore(
            gallery: gallery,
            canvasColor: displaySettingsManager.settings.canvasColor,
            canvasPadding: displaySettingsManager.settings.canvasPadding
        ) { context in
            tvOSOverlayView(context: context)
        }
        .focusable()
        .onMoveCommand { direction in
            handleMoveCommand(direction, context: nil) // Handled via overlay
        }
        .onPlayPauseCommand {
            // Handled via overlay
        }
        .onExitCommand {
            dismiss()
        }
        .task {
            await displaySettingsManager.loadSettings()
        }
    }

    // MARK: - tvOS Overlay View

    @ViewBuilder
    private func tvOSOverlayView(context: SlideshowOverlayContext) -> some View {
        VStack {
            Spacer()

            HStack {
                // Gallery info
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.gallery.name)
                        .font(.title)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        // Image counter
                        if context.imageCount > 0 {
                            Text("\(context.currentIndex + 1) of \(context.imageCount)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        // Playback status
                        HStack(spacing: 6) {
                            Image(systemName: context.isPlaying ? "play.fill" : "pause.fill")
                            Text(context.isPlaying ? "Playing" : "Paused")
                        }
                        .font(.headline)
                        .foregroundStyle(context.isPlaying ? .green : .secondary)
                    }

                    // Current image filename
                    if let currentImage = context.currentImage {
                        Text(currentImage.filename)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Controls hint
                VStack(alignment: .trailing, spacing: 4) {
                    controlHint(icon: "playpause", text: "Play/Pause")
                    controlHint(icon: "arrow.left.arrow.right", text: "Previous/Next")
                    controlHint(icon: "arrow.uturn.backward", text: "Back to Galleries")
                }
            }
            .padding(48)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .focusable()
        .onMoveCommand { direction in
            handleMoveCommand(direction, context: context)
        }
        .onPlayPauseCommand {
            context.togglePlayPause()
        }
        .onExitCommand {
            dismiss()
        }
    }

    private func controlHint(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 24)
            Text(text)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - Remote Commands

    private func handleMoveCommand(_ direction: MoveCommandDirection, context: SlideshowOverlayContext?) {
        guard let context = context else { return }

        switch direction {
        case .left:
            context.previous()
        case .right:
            context.next()
        case .up, .down:
            // Show overlay on up/down
            context.flashOverlay()
        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview("Slideshow View") {
    SlideshowView(
        gallery: Gallery(
            name: "Preview Gallery",
            folderURL: URL(fileURLWithPath: "/tmp")
        )
    )
}
