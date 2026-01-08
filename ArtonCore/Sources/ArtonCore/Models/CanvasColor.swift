import Foundation

/// Background color for the artwork canvas on tvOS
public enum CanvasColor: String, Codable, Sendable, CaseIterable {
    case black
    case eggshell

    public var displayName: String {
        switch self {
        case .black: return "Black"
        case .eggshell: return "Eggshell"
        }
    }
}
