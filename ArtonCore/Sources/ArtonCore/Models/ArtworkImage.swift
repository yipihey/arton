import Foundation
import CryptoKit

/// An individual artwork image within a gallery
public struct ArtworkImage: Identifiable, Sendable, Hashable {
    /// Stable ID derived from the relative path within the gallery
    public let id: String
    public let fileURL: URL
    public let filename: String

    /// Lowercase filename for case-insensitive sorting
    public var sortKey: String

    /// Whether the file is locally available (not evicted by iCloud)
    public var isDownloaded: Bool

    /// File size in bytes (nil if not yet determined)
    public var fileSizeBytes: Int64?

    /// Image dimensions (nil if not yet loaded)
    public var dimensions: CGSize?

    public init(
        fileURL: URL,
        galleryURL: URL,
        isDownloaded: Bool = true,
        fileSizeBytes: Int64? = nil,
        dimensions: CGSize? = nil
    ) {
        self.fileURL = fileURL
        self.filename = fileURL.lastPathComponent
        self.sortKey = fileURL.lastPathComponent.lowercased()
        self.isDownloaded = isDownloaded
        self.fileSizeBytes = fileSizeBytes
        self.dimensions = dimensions

        // Generate stable ID from relative path within gallery
        let relativePath = fileURL.path.replacingOccurrences(
            of: galleryURL.path,
            with: ""
        )
        let data = Data(relativePath.utf8)
        let hash = SHA256.hash(data: data)
        self.id = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ArtworkImage, rhs: ArtworkImage) -> Bool {
        lhs.id == rhs.id
    }

    /// Supported image file extensions
    public static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "gif"
    ]

    /// Check if a URL points to a supported image file
    public static func isSupportedImage(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }
}
