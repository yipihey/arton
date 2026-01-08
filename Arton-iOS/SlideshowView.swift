import SwiftUI
import ArtonCore

/// Full-screen slideshow view for iOS Display Mode
/// Displays artwork images with touch gesture controls
struct SlideshowView: View {
    let gallery: Gallery

    @StateObject private var slideshowController = SlideshowController()
    @State private var settings: GallerySettings = .default
    @State private var isLoadingImages: Bool = true
    @State private var loadError: String?
    @State private var showOverlay: Bool = true
    @State private var overlayHideTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main artwork display
                ArtworkDisplayView(
                    image: slideshowController.currentImage,
                    canvasColor: .black,
                    canvasPadding: 0.02,
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
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .gesture(tapGesture)
        .gesture(swipeGesture)
        .animation(.easeInOut(duration: 0.3), value: showOverlay)
        .task {
            await loadGalleryContent()
        }
        .onAppear {
            // Keep screen awake during slideshow
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            // Re-enable auto-lock when leaving
            UIApplication.shared.isIdleTimerDisabled = false
            slideshowController.pause()
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

    // MARK: - Gestures

    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded { _ in
                if showOverlay {
                    // If overlay showing, tap toggles play/pause
                    togglePlayPause()
                } else {
                    // If overlay hidden, tap shows it
                    showOverlay = true
                    if slideshowController.isPlaying {
                        scheduleOverlayHide()
                    }
                }
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height

                // Only handle horizontal swipes
                if abs(horizontalAmount) > abs(verticalAmount) {
                    if horizontalAmount < 0 {
                        // Swipe left = next
                        slideshowController.next()
                        flashOverlay()
                    } else {
                        // Swipe right = previous
                        slideshowController.previous()
                        flashOverlay()
                    }
                }
            }
    }

    // MARK: - Overlay View

    private var overlayView: some View {
        ZStack {
            // Semi-transparent background for controls visibility
            Color.black.opacity(0.001) // Minimal opacity to capture taps

            VStack {
                // Top bar with close button
                HStack {
                    Spacer()

                    Button {
                        handleExit()
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
                if !slideshowController.isPlaying && !isLoadingImages {
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 8)
                    }
                }

                Spacer()

                // Bottom info bar
                bottomInfoBar
            }
        }
    }

    private var bottomInfoBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Gallery info
                VStack(alignment: .leading, spacing: 4) {
                    Text(gallery.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        // Image counter
                        if !slideshowController.images.isEmpty {
                            Text("\(slideshowController.currentIndex + 1) of \(slideshowController.images.count)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        // Playback status
                        HStack(spacing: 4) {
                            Image(systemName: slideshowController.isPlaying ? "play.fill" : "pause.fill")
                                .font(.caption)
                            Text(slideshowController.isPlaying ? "Playing" : "Paused")
                                .font(.subheadline)
                        }
                        .foregroundStyle(slideshowController.isPlaying ? .green : .white.opacity(0.7))
                    }
                }

                Spacer()

                // Playback controls
                HStack(spacing: 24) {
                    Button {
                        slideshowController.previous()
                        flashOverlay()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: slideshowController.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                    Button {
                        slideshowController.next()
                        flashOverlay()
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading images...")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            Text("Unable to Load Gallery")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("Close") {
                handleExit()
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    // MARK: - Actions

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

        do {
            // Load gallery settings
            settings = try await GalleryManager.shared.loadSettings(for: gallery)

            // Load images
            let images = try await GalleryManager.shared.loadImages(for: gallery)

            if images.isEmpty {
                loadError = "This gallery has no images. Add images to start the slideshow."
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
