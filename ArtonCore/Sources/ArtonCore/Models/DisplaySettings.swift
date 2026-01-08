import Foundation

/// Global display settings for the tvOS app
public struct DisplaySettings: Codable, Sendable, Equatable {
    /// Background color for the canvas
    public var canvasColor: CanvasColor

    /// Padding around the image as a fraction (0.0 - 0.25)
    public var canvasPadding: Double

    /// Currently selected gallery ID
    public var selectedGalleryID: UUID?

    public init(
        canvasColor: CanvasColor = .black,
        canvasPadding: Double = 0,
        selectedGalleryID: UUID? = nil
    ) {
        self.canvasColor = canvasColor
        self.canvasPadding = min(max(canvasPadding, 0), 0.25)
        self.selectedGalleryID = selectedGalleryID
    }

    /// Preset padding values
    public static let paddingPresets: [(name: String, value: Double)] = [
        ("None", 0),
        ("5%", 0.05),
        ("10%", 0.10),
        ("15%", 0.15),
        ("20%", 0.20),
        ("25%", 0.25)
    ]
}
