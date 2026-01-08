import Foundation

/// Per-gallery display settings, stored in .arton-settings.json within the gallery folder
public struct GallerySettings: Codable, Sendable, Equatable {
    /// Order in which images are displayed
    public var displayOrder: DisplayOrder

    /// Transition effect between images
    public var transitionEffect: TransitionEffect

    /// Custom transition duration (nil uses the effect's default)
    public var transitionDuration: TimeInterval?

    /// Time to display each image in seconds
    public var displayInterval: TimeInterval

    /// The filename for storing settings in each gallery folder
    public static let filename = ".arton-settings.json"

    public init(
        displayOrder: DisplayOrder = .serial,
        transitionEffect: TransitionEffect = .fade,
        transitionDuration: TimeInterval? = nil,
        displayInterval: TimeInterval = 30
    ) {
        self.displayOrder = displayOrder
        self.transitionEffect = transitionEffect
        self.transitionDuration = transitionDuration
        self.displayInterval = displayInterval
    }

    /// The effective transition duration (custom or default for the effect)
    public var effectiveTransitionDuration: TimeInterval {
        transitionDuration ?? transitionEffect.defaultDuration
    }

    /// Default settings for new galleries
    public static let `default` = GallerySettings()

    /// Preset display intervals with human-readable names
    public static let intervalPresets: [(name: String, seconds: TimeInterval)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("30 minutes", 1800),
        ("1 hour", 3600)
    ]
}
