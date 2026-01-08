import SwiftUI

/// Core slideshow view providing shared functionality across platforms
///
/// This view handles:
/// - Image loading and display via ArtworkDisplayView
/// - Slideshow controller integration
/// - Loading and error states
/// - Overlay visibility management
///
/// Platform-specific controls (gestures, remote commands) are provided via the overlayContent ViewBuilder
public struct SlideshowViewCore<OverlayContent: View>: View {
    let gallery: Gallery
    let canvasColor: CanvasColor
    let canvasPadding: Double
    @ViewBuilder let overlayContent: (SlideshowOverlayContext) -> OverlayContent

    @StateObject private var slideshowController = SlideshowController()
    @State private var settings: GallerySettings = .default
    @State private var isLoadingImages: Bool = true
    @State private var loadError: String?
    @State private var showOverlay: Bool = true
    @State private var overlayHideTask: Task<Void, Never>?

    public init(
        gallery: Gallery,
        canvasColor: CanvasColor = .black,
        canvasPadding: Double = 0.02,
        @ViewBuilder overlayContent: @escaping (SlideshowOverlayContext) -> OverlayContent
    ) {
        self.gallery = gallery
        self.canvasColor = canvasColor
        self.canvasPadding = canvasPadding
        self.overlayContent = overlayContent
    }

    public var body: some View {
        ZStack {
            // Main artwork display
            ArtworkDisplayView(
                image: slideshowController.currentImage,
                canvasColor: canvasColor,
                canvasPadding: canvasPadding,
                transitionEffect: settings.transitionEffect
            )
            .ignoresSafeArea()

            // Platform-specific overlay
            if showOverlay {
                overlayContent(overlayContext)
                    .transition(.opacity)
            }

            // Loading indicator
            if isLoadingImages {
                SlideshowLoadingView()
            }

            // Error view
            if let error = loadError {
                SlideshowErrorView(message: error)
            }
        }
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

    // MARK: - Overlay Context

    private var overlayContext: SlideshowOverlayContext {
        SlideshowOverlayContext(
            gallery: gallery,
            controller: slideshowController,
            isLoading: isLoadingImages,
            togglePlayPause: togglePlayPause,
            next: {
                slideshowController.next()
                flashOverlay()
            },
            previous: {
                slideshowController.previous()
                flashOverlay()
            },
            flashOverlay: flashOverlay,
            hideOverlay: { showOverlay = false }
        )
    }

    // MARK: - Actions

    private func togglePlayPause() {
        if slideshowController.isPlaying {
            slideshowController.pause()
        } else {
            slideshowController.play()
        }
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
                loadError = "This gallery has no images."
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

// MARK: - Overlay Context

/// Context passed to overlay content for platform-specific UI
@MainActor
public struct SlideshowOverlayContext {
    public let gallery: Gallery
    public let controller: SlideshowController
    public let isLoading: Bool
    public let togglePlayPause: () -> Void
    public let next: () -> Void
    public let previous: () -> Void
    public let flashOverlay: () -> Void
    public let hideOverlay: () -> Void

    public var currentIndex: Int { controller.currentIndex }
    public var imageCount: Int { controller.images.count }
    public var isPlaying: Bool { controller.isPlaying }
    public var currentImage: ArtworkImage? { controller.currentImage }
}

// MARK: - Shared Loading View

/// Loading view displayed while images are loading
public struct SlideshowLoadingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                #if os(tvOS)
                .scaleEffect(1.5) // Extra scale for tvOS
                #endif

            Text("Loading images...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

// MARK: - Shared Error View

/// Error view displayed when gallery loading fails
public struct SlideshowErrorView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 24) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
