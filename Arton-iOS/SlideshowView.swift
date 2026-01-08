import SwiftUI
import ArtonCore

/// Full-screen slideshow view for iOS Display Mode
/// Displays artwork images with touch gesture controls
struct SlideshowView: View {
    let gallery: Gallery

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            SlideshowViewCore(gallery: gallery) { context in
                iOSOverlayView(context: context)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .gesture(tapGesture(context: nil)) // Placeholder - actual context handled inside
            .gesture(swipeGesture(context: nil))
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            // Keep screen awake during slideshow
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable auto-lock when leaving
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - iOS Overlay View

    @ViewBuilder
    private func iOSOverlayView(context: SlideshowOverlayContext) -> some View {
        ZStack {
            // Semi-transparent background for controls visibility
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .gesture(tapGesture(context: context))
                .gesture(swipeGesture(context: context))

            VStack {
                // Top bar with close button
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .padding(20)
                }

                Spacer()

                // Center play/pause indicator
                if !context.isPlaying && !context.isLoading {
                    Button {
                        context.togglePlayPause()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 8)
                    }
                }

                Spacer()

                // Bottom info bar
                bottomInfoBar(context: context)
            }
        }
    }

    private func bottomInfoBar(context: SlideshowOverlayContext) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Gallery info
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.gallery.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        // Image counter
                        if context.imageCount > 0 {
                            Text("\(context.currentIndex + 1) of \(context.imageCount)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        // Playback status
                        HStack(spacing: 4) {
                            Image(systemName: context.isPlaying ? "play.fill" : "pause.fill")
                                .font(.caption)
                            Text(context.isPlaying ? "Playing" : "Paused")
                                .font(.subheadline)
                        }
                        .foregroundStyle(context.isPlaying ? .green : .white.opacity(0.7))
                    }
                }

                Spacer()

                // Playback controls
                HStack(spacing: 24) {
                    Button {
                        context.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    Button {
                        context.togglePlayPause()
                    } label: {
                        Image(systemName: context.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                    Button {
                        context.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Gestures

    private func tapGesture(context: SlideshowOverlayContext?) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                context?.togglePlayPause()
            }
    }

    private func swipeGesture(context: SlideshowOverlayContext?) -> some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard let context = context else { return }

                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height

                // Only handle horizontal swipes
                if abs(horizontalAmount) > abs(verticalAmount) {
                    if horizontalAmount < 0 {
                        // Swipe left = next
                        context.next()
                    } else {
                        // Swipe right = previous
                        context.previous()
                    }
                }
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
