import Foundation

/// Visual transition effect between artwork images
public enum TransitionEffect: String, Codable, Sendable, CaseIterable {
    case fade
    case slide
    case dissolve
    case push
    case none

    public var displayName: String {
        switch self {
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .dissolve: return "Dissolve"
        case .push: return "Push"
        case .none: return "None"
        }
    }

    /// Default duration for this transition effect in seconds
    public var defaultDuration: TimeInterval {
        switch self {
        case .none: return 0
        case .fade, .dissolve: return 1.0
        case .slide, .push: return 0.5
        }
    }
}
