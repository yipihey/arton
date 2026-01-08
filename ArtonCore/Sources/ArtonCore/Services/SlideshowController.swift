import Foundation
import Combine

/// Controls the slideshow playback for displaying artwork images on tvOS
@MainActor
public class SlideshowController: ObservableObject {
    // MARK: - Published Properties

    /// The currently displayed artwork image
    @Published public private(set) var currentImage: ArtworkImage?

    /// Index of the current image in the images array
    @Published public private(set) var currentIndex: Int = 0

    /// Whether the slideshow is actively playing
    @Published public private(set) var isPlaying: Bool = false

    /// All images loaded for the current slideshow
    @Published public private(set) var images: [ArtworkImage] = []

    // MARK: - Public Properties

    /// Gallery settings controlling display order, transition, and timing
    public var settings: GallerySettings = .default

    // MARK: - Private Properties

    /// Task for the automatic advancement timer
    private var timerTask: Task<Void, Never>?

    /// Direction for ping-pong mode (true = forward, false = backward)
    private var isMovingForward: Bool = true

    // MARK: - Initialization

    public init() {}

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Load a gallery's images for slideshow
    /// - Parameters:
    ///   - images: Array of artwork images to display
    ///   - settings: Gallery settings for display order and timing
    public func load(images: [ArtworkImage], settings: GallerySettings) {
        // Cancel any existing timer
        stopTimer()

        // Reset state
        self.images = images
        self.settings = settings
        self.currentIndex = 0
        self.isMovingForward = true
        self.isPlaying = false

        // Set current image if available
        if images.isEmpty {
            currentImage = nil
        } else {
            currentImage = images[0]
        }
    }

    /// Start or resume the slideshow
    public func play() {
        guard !images.isEmpty else { return }
        guard !isPlaying else { return }

        isPlaying = true
        startTimer()
    }

    /// Pause the slideshow
    public func pause() {
        isPlaying = false
        stopTimer()
    }

    /// Advance to the next image based on display order
    public func next() {
        guard !images.isEmpty else { return }

        let nextIndex = calculateNextIndex()
        goTo(index: nextIndex)
    }

    /// Go back to the previous image based on display order
    public func previous() {
        guard !images.isEmpty else { return }

        let previousIndex = calculatePreviousIndex()
        goTo(index: previousIndex)
    }

    /// Jump to a specific index
    /// - Parameter index: The index to jump to (will be clamped to valid range)
    public func goTo(index: Int) {
        guard !images.isEmpty else { return }

        // Clamp index to valid range
        let clampedIndex = max(0, min(index, images.count - 1))
        currentIndex = clampedIndex
        currentImage = images[clampedIndex]

        // Restart timer if playing to reset the interval
        if isPlaying {
            restartTimer()
        }
    }

    // MARK: - Private Methods

    /// Calculate the next index based on display order
    private func calculateNextIndex() -> Int {
        guard images.count > 1 else { return 0 }

        switch settings.displayOrder {
        case .serial:
            return (currentIndex + 1) % images.count

        case .random:
            return randomNextIndex()

        case .pingPong:
            return pingPongNextIndex()
        }
    }

    /// Calculate the previous index based on display order
    private func calculatePreviousIndex() -> Int {
        guard images.count > 1 else { return 0 }

        switch settings.displayOrder {
        case .serial:
            return (currentIndex - 1 + images.count) % images.count

        case .random:
            // For random mode, previous still picks a random image
            return randomNextIndex()

        case .pingPong:
            return pingPongPreviousIndex()
        }
    }

    /// Get a random next index, avoiding the current index if possible
    private func randomNextIndex() -> Int {
        guard images.count > 1 else { return 0 }

        // Generate a random index different from current
        var nextIndex: Int
        repeat {
            nextIndex = Int.random(in: 0..<images.count)
        } while nextIndex == currentIndex

        return nextIndex
    }

    /// Calculate next index for ping-pong mode
    private func pingPongNextIndex() -> Int {
        if isMovingForward {
            if currentIndex >= images.count - 1 {
                // At the end, reverse direction
                isMovingForward = false
                return currentIndex - 1
            } else {
                return currentIndex + 1
            }
        } else {
            if currentIndex <= 0 {
                // At the beginning, reverse direction
                isMovingForward = true
                return currentIndex + 1
            } else {
                return currentIndex - 1
            }
        }
    }

    /// Calculate previous index for ping-pong mode
    private func pingPongPreviousIndex() -> Int {
        // Reverse the direction logic for previous
        if isMovingForward {
            if currentIndex <= 0 {
                // At the beginning going forward, go to 1
                return min(1, images.count - 1)
            } else {
                return currentIndex - 1
            }
        } else {
            if currentIndex >= images.count - 1 {
                // At the end going backward, go to second-to-last
                return max(images.count - 2, 0)
            } else {
                return currentIndex + 1
            }
        }
    }

    /// Start the automatic advancement timer
    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                let interval = self.settings.displayInterval

                // Sleep for the display interval
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    // Task was cancelled
                    break
                }

                // Check if still playing after sleep
                guard !Task.isCancelled else { break }

                // Advance to next image
                await MainActor.run {
                    if self.isPlaying {
                        self.next()
                    }
                }
            }
        }
    }

    /// Stop the automatic advancement timer
    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// Restart the timer (used when manually navigating while playing)
    private func restartTimer() {
        stopTimer()
        startTimer()
    }
}
