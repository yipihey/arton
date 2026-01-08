import Foundation
import CloudKit

/// A gallery that has been shared to CloudKit for public or private access
public struct SharedGallery: Identifiable, Sendable, Hashable {
    /// CloudKit record ID (used as the primary identifier)
    public let id: String

    /// Original local gallery UUID
    public let galleryID: UUID

    /// Gallery name
    public var name: String

    /// Optional description
    public var description: String?

    /// Display name of the gallery owner
    public var ownerName: String

    /// CloudKit record ID of the owner
    public var ownerRecordID: String

    /// Number of images in the gallery
    public var imageCount: Int

    /// Thumbnail image data for the poster
    public var posterImageData: Data?

    /// Whether this gallery appears in the Explore section
    public var isPublic: Bool

    /// When the gallery was first shared
    public var createdAt: Date

    /// When the gallery was last updated
    public var updatedAt: Date

    /// Tags for future filtering/categorization
    public var tags: [String]

    // MARK: - Computed Properties

    /// Deep link URL for sharing
    public var shareURL: URL {
        URL(string: "arton://gallery/\(id)")!
    }

    // MARK: - Initialization

    public init(
        id: String,
        galleryID: UUID,
        name: String,
        description: String? = nil,
        ownerName: String,
        ownerRecordID: String,
        imageCount: Int,
        posterImageData: Data? = nil,
        isPublic: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.galleryID = galleryID
        self.name = name
        self.description = description
        self.ownerName = ownerName
        self.ownerRecordID = ownerRecordID
        self.imageCount = imageCount
        self.posterImageData = posterImageData
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }

    // MARK: - CloudKit Record Conversion

    /// CloudKit record type name
    public static let recordType = "SharedGallery"

    /// CloudKit field keys
    public enum FieldKey: String {
        case galleryID
        case name
        case description
        case ownerName
        case ownerRecordID
        case imageCount
        case posterImageData
        case isPublic
        case createdAt
        case updatedAt
        case tags
    }

    /// Initialize from a CloudKit record
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }

        self.id = record.recordID.recordName

        guard let galleryIDString = record[FieldKey.galleryID.rawValue] as? String,
              let galleryID = UUID(uuidString: galleryIDString),
              let name = record[FieldKey.name.rawValue] as? String,
              let ownerName = record[FieldKey.ownerName.rawValue] as? String,
              let ownerRecordID = record[FieldKey.ownerRecordID.rawValue] as? String,
              let imageCount = record[FieldKey.imageCount.rawValue] as? Int64,
              let isPublic = record[FieldKey.isPublic.rawValue] as? Int64,
              let createdAt = record[FieldKey.createdAt.rawValue] as? Date,
              let updatedAt = record[FieldKey.updatedAt.rawValue] as? Date
        else {
            return nil
        }

        self.galleryID = galleryID
        self.name = name
        self.description = record[FieldKey.description.rawValue] as? String
        self.ownerName = ownerName
        self.ownerRecordID = ownerRecordID
        self.imageCount = Int(imageCount)
        self.posterImageData = record[FieldKey.posterImageData.rawValue] as? Data
        self.isPublic = isPublic == 1
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = record[FieldKey.tags.rawValue] as? [String] ?? []
    }

    /// Convert to a CloudKit record
    public func toRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let id = recordID ?? CKRecord.ID(recordName: self.id)
        let record = CKRecord(recordType: Self.recordType, recordID: id)

        record[FieldKey.galleryID.rawValue] = galleryID.uuidString
        record[FieldKey.name.rawValue] = name
        record[FieldKey.description.rawValue] = description
        record[FieldKey.ownerName.rawValue] = ownerName
        record[FieldKey.ownerRecordID.rawValue] = ownerRecordID
        record[FieldKey.imageCount.rawValue] = Int64(imageCount)
        record[FieldKey.posterImageData.rawValue] = posterImageData
        record[FieldKey.isPublic.rawValue] = isPublic ? Int64(1) : Int64(0)
        record[FieldKey.createdAt.rawValue] = createdAt
        record[FieldKey.updatedAt.rawValue] = updatedAt
        record[FieldKey.tags.rawValue] = tags

        return record
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SharedGallery, rhs: SharedGallery) -> Bool {
        lhs.id == rhs.id
    }
}
