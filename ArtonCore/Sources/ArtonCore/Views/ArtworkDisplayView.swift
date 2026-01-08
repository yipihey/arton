import SwiftUI

/// Full-screen view for displaying artwork during slideshow
/// Designed primarily for tvOS but works across all platforms
public struct ArtworkDisplayView: View {
    let image: ArtworkImage?
    var canvasColor: CanvasColor = .black
    var canvasPadding: Double = 0
    var transitionEffect: TransitionEffect = .fade

    @State private var loadedImage: PlatformImage?
    @State private var currentImageID: String?
    @State private var isFirstLoad: Bool = true

    public init(
        image: ArtworkImage?,
        canvasColor: CanvasColor = .black,
        canvasPadding: Double = 0,
        transitionEffect: TransitionEffect = .fade
    ) {
        self.image = image
        self.canvasColor = canvasColor
        self.canvasPadding = canvasPadding
        self.transitionEffect = transitionEffect
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background - explicitly not animated
                canvasBackgroundColor
                    .ignoresSafeArea()
                    .animation(nil, value: canvasColor)

                // Artwork container with transitions
                // Using a ZStack with unique ID ensures proper transition behavior
                if let loadedImage = loadedImage, let imageID = currentImageID {
                    artworkImageView(loadedImage, in: geometry.size)
                        .id(imageID)
                        .transition(transition(for: transitionEffect, isFirstLoad: isFirstLoad))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Only animate image transitions, not canvas changes
        .animation(animation(for: transitionEffect, isFirstLoad: isFirstLoad), value: currentImageID)
        .task(id: image?.id) {
            await loadFullResolutionImage()
        }
    }

    // MARK: - Private Views

    private var canvasBackgroundColor: Color {
        switch canvasColor {
        case .black:
            return .black
        case .eggshell:
            return Color(white: 0.95)
        }
    }

    private func artworkImageView(_ platformImage: PlatformImage, in size: CGSize) -> some View {
        // Calculate padded frame size
        let paddingFactor = 1.0 - (canvasPadding * 2)
        let paddedWidth = size.width * paddingFactor
        let paddedHeight = size.height * paddingFactor

        return Group {
            #if canImport(UIKit)
            Image(uiImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
            #elseif canImport(AppKit)
            Image(nsImage: platformImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
            #endif
        }
        .frame(maxWidth: paddedWidth, maxHeight: paddedHeight)
    }

    // MARK: - Transitions

    /// Creates a polished transition effect based on the specified type
    /// - Parameters:
    ///   - effect: The type of transition to create
    ///   - isFirstLoad: Whether this is the first image being displayed (uses simpler fade-in)
    private func transition(for effect: TransitionEffect, isFirstLoad: Bool) -> AnyTransition {
        // For first load, use a simple elegant fade-in regardless of selected transition
        if isFirstLoad {
            return .opacity.combined(with: .scale(scale: 0.95))
        }

        switch effect {
        case .fade:
            // Smooth fade with subtle scale for added depth and visual interest
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 1.02)),
                removal: .opacity.combined(with: .scale(scale: 0.98))
            )

        case .slide:
            // Clean slide transition: new image enters from right, old exits left
            // Combined with slight opacity fade for smoother edges
            return .asymmetric(
                insertion: .move(edge: .trailing)
                    .combined(with: .opacity),
                removal: .move(edge: .leading)
                    .combined(with: .opacity)
            )

        case .dissolve:
            // Cross-dissolve with scale effect creates depth and dimension
            // The incoming image scales up slightly while fading in
            // The outgoing image scales down slightly while fading out
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92)),
                removal: .opacity.combined(with: .scale(scale: 1.08))
            )

        case .push:
            // Push transition mimics UIKit's push navigation
            // New image pushes in from right while old image is pushed left
            // Includes opacity for smoother visual continuity
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
                    .combined(with: .opacity)
            )

        case .none:
            // Instant change with no animation
            return .identity
        }
    }

    /// Creates an appropriate animation curve for the transition effect
    /// - Parameters:
    ///   - effect: The type of transition being animated
    ///   - isFirstLoad: Whether this is the first image (uses different timing)
    private func animation(for effect: TransitionEffect, isFirstLoad: Bool) -> Animation? {
        // First load uses a gentle fade-in
        if isFirstLoad {
            return .easeOut(duration: 0.6)
        }

        switch effect {
        case .none:
            // No animation for instant transitions
            return nil

        case .fade:
            // Smooth easeInOut for fade creates a pleasant, natural feel
            return .easeInOut(duration: 0.8)

        case .dissolve:
            // Longer duration for dissolve allows the scale effect to be appreciated
            // Using a custom spring for organic movement
            return .spring(duration: 1.0, bounce: 0.0, blendDuration: 0.3)

        case .slide:
            // Quick, snappy slide with slight spring for natural deceleration
            return .spring(duration: 0.6, bounce: 0.1, blendDuration: 0.2)

        case .push:
            // Push uses easeInOut for consistent, professional feel
            // Slightly longer than slide for more deliberate movement
            return .easeInOut(duration: 0.5)
        }
    }

    // MARK: - Image Loading

    private func loadFullResolutionImage() async {
        guard let image = image else {
            loadedImage = nil
            currentImageID = nil
            return
        }

        // Load image on background thread to avoid blocking UI
        let loaded = await Task.detached(priority: .userInitiated) {
            ImageUtilities.loadImage(from: image.fileURL)
        }.value

        // Update on main thread with proper state management for transitions
        await MainActor.run {
            // Track if this is the first image being loaded
            let wasFirstLoad = isFirstLoad

            // Update the loaded image and its ID together to trigger transition
            loadedImage = loaded
            currentImageID = image.id

            // After first successful load, subsequent loads use full transitions
            if wasFirstLoad && loaded != nil {
                // Delay resetting isFirstLoad to ensure the first animation completes
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(700))
                    isFirstLoad = false
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ArtworkDisplayView - Black Canvas") {
    ArtworkDisplayView(
        image: nil,
        canvasColor: .black,
        canvasPadding: 0.05
    )
}

#Preview("ArtworkDisplayView - Eggshell Canvas") {
    ArtworkDisplayView(
        image: nil,
        canvasColor: .eggshell,
        canvasPadding: 0.1
    )
}
#endif
