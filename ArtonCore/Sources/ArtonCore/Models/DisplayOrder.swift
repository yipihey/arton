import Foundation

/// Determines the order in which artwork images are displayed in a slideshow
public enum DisplayOrder: String, Codable, Sendable, CaseIterable {
    /// Images displayed in alphabetical order by filename
    case serial
    /// Images displayed in random order
    case random
    /// Images displayed forward then backward (ping-pong)
    case pingPong

    public var displayName: String {
        switch self {
        case .serial: return "In Order"
        case .random: return "Shuffle"
        case .pingPong: return "Back & Forth"
        }
    }
}
