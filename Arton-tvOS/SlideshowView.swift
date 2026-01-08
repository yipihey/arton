import SwiftUI
import ArtonCore

/// Full-screen slideshow view for tvOS
/// Displays artwork images with Siri Remote control support
struct SlideshowView: View {
    let gallery: Gallery

    @StateObject private var slideshowController = SlideshowController()
    @StateObject private var displaySettingsManager = DisplaySettingsManager.shared
    @State private var settings: GallerySettings = .default
    @State private var isLoadingImages: Bool = true
    @State private var loadError: String?
    @State private var showOverlay: Bool = true
    @State private var overlayHideTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Main artwork display
            ArtworkDisplayView(
                image: slideshowController.currentImage,
                canvasColor: displaySettingsManager.settings.canvasColor,
                canvasPadding: displaySettingsManager.settings.canvasPadding,
                transitionEffect: settings.transitionEffect
            )
            .ignoresSafeArea()

            // Overlay when paused or initially shown
            if showOverlay {
                overlayView
                    .transition(.opacity)
            }

            // Loading indicator
            if isLoadingImages {
                loadingView
            }

            // Error view
            if let error = loadError {
                errorView(message: error)
            }
        }
        .focusable()
        .onMoveCommand(perform: handleMoveCommand)
        .onPlayPauseCommand(perform: togglePlayPause)
        .onExitCommand(perform: handleExit)
        .animation(.easeInOut(duration: 0.3), value: showOverlay)
        .task {
            await loadGalleryContent()
        }
        .onChange(of: slideshowController.isPlaying) { _, isPlaying in
            if isPlaying {
                scheduleOverlayHide()
            } else {
                showOverlay = true
                overlayHideTask?.cancel()
            }
        }
    }

    // MARK: - Overlay View

    private var overlayView: some View {
        VStack {
            Spacer()

            HStack {
                // Gallery info
                VStack(alignment: .leading, spacing: 8) {
                    Text(gallery.name)
                        .font(.title)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        // Image counter
                        Text("\(slideshowController.currentIndex + 1) of \(slideshowController.images.count)")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        // Playback status
                        HStack(spacing: 6) {
                            Image(systemName: slideshowController.isPlaying ? "play.fill" : "pause.fill")
                            Text(slideshowController.isPlaying ? "Playing" : "Paused")
                        }
                        .font(.headline)
                        .foregroundStyle(slideshowController.isPlaying ? .green : .secondary)
                    }

                    // Current image filename
                    if let currentImage = slideshowController.currentImage {
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)

            Text("Loading images...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("Unable to Load Gallery")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Remote Commands

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            slideshowController.previous()
            flashOverlay()
        case .right:
            slideshowController.next()
            flashOverlay()
        case .up, .down:
            // Show/hide overlay on up/down
            showOverlay.toggle()
            if showOverlay && slideshowController.isPlaying {
                scheduleOverlayHide()
            }
        @unknown default:
            break
        }
    }

    private func togglePlayPause() {
        if slideshowController.isPlaying {
            slideshowController.pause()
        } else {
            slideshowController.play()
        }
    }

    private func handleExit() {
        slideshowController.pause()
        dismiss()
    }

    // MARK: - Overlay Management

    private func scheduleOverlayHide() {
        overlayHideTask?.cancel()
        overlayHideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled && slideshowController.isPlaying {
                showOverlay = false
            }
        }
    }

    private func flashOverlay() {
        showOverlay = true
        if slideshowController.isPlaying {
            scheduleOverlayHide()
        }
    }

    // MARK: - Data Loading

    private func loadGalleryContent() async {
        isLoadingImages = true
        loadError = nil

        // Load display settings
        await displaySettingsManager.loadSettings()

        do {
            // Load gallery settings
            settings = try await GalleryManager.shared.loadSettings(for: gallery)

            // Load images
            let images = try await GalleryManager.shared.loadImages(for: gallery)

            if images.isEmpty {
                loadError = "This gallery has no images. Add images using the Arton app on iOS or macOS."
                isLoadingImages = false
                return
            }

            // Configure slideshow controller
            slideshowController.load(images: images, settings: settings)

            isLoadingImages = false

            // Auto-start playback after a short delay
            try? await Task.sleep(for: .seconds(0.5))
            slideshowController.play()

        } catch {
            loadError = error.localizedDescription
            isLoadingImages = false
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
