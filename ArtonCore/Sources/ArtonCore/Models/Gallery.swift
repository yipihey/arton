import Foundation

/// A collection of artwork images stored as a folder in iCloud Drive
public struct Gallery: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var folderURL: URL
    public var createdAt: Date
    public var modifiedAt: Date

    /// Cached image count to avoid enumeration on every load
    /// This is updated when images are added/removed
    public var cachedImageCount: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        folderURL: URL,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        cachedImageCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.folderURL = folderURL
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.cachedImageCount = cachedImageCount
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        lhs.id == rhs.id
    }
}
