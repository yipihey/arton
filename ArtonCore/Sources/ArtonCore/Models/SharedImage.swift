import Foundation
import CloudKit

/// An image within a shared gallery, stored in CloudKit
public struct SharedImage: Identifiable, Sendable, Hashable {
    /// CloudKit record ID
    public let id: String

    /// Parent gallery's CloudKit record ID
    public let galleryRecordID: String

    /// Original filename
    public var filename: String

    /// Sort order within the gallery
    public var sortOrder: Int

    /// Image width in pixels
    public var width: Int

    /// Image height in pixels
    public var height: Int

    /// File size in bytes
    public var fileSizeBytes: Int64

    /// The CKAsset URL for downloading (populated when fetching)
    public var assetURL: URL?

    // MARK: - Computed Properties

    /// Image dimensions as CGSize
    public var dimensions: CGSize {
        CGSize(width: Double(width), height: Double(height))
    }

    /// Aspect ratio (width / height)
    public var aspectRatio: Double {
        guard height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    // MARK: - Initialization

    public init(
        id: String,
        galleryRecordID: String,
        filename: String,
        sortOrder: Int,
        width: Int,
        height: Int,
        fileSizeBytes: Int64,
        assetURL: URL? = nil
    ) {
        self.id = id
        self.galleryRecordID = galleryRecordID
        self.filename = filename
        self.sortOrder = sortOrder
        self.width = width
        self.height = height
        self.fileSizeBytes = fileSizeBytes
        self.assetURL = assetURL
    }

    // MARK: - CloudKit Record Conversion

    /// CloudKit record type name
    public static let recordType = "SharedImage"

    /// CloudKit field keys
    public enum FieldKey: String {
        case gallery
        case imageAsset
        case filename
        case sortOrder
        case width
        case height
        case fileSizeBytes
    }

    /// Initialize from a CloudKit record
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }

        self.id = record.recordID.recordName

        guard let galleryRef = record[FieldKey.gallery.rawValue] as? CKRecord.Reference,
              let filename = record[FieldKey.filename.rawValue] as? String,
              let sortOrder = record[FieldKey.sortOrder.rawValue] as? Int64,
              let width = record[FieldKey.width.rawValue] as? Int64,
              let height = record[FieldKey.height.rawValue] as? Int64,
              let fileSizeBytes = record[FieldKey.fileSizeBytes.rawValue] as? Int64
        else {
            return nil
        }

        self.galleryRecordID = galleryRef.recordID.recordName
        self.filename = filename
        self.sortOrder = Int(sortOrder)
        self.width = Int(width)
        self.height = Int(height)
        self.fileSizeBytes = fileSizeBytes

        // Extract asset URL if available
        if let asset = record[FieldKey.imageAsset.rawValue] as? CKAsset {
            self.assetURL = asset.fileURL
        } else {
            self.assetURL = nil
        }
    }

    /// Convert to a CloudKit record
    /// Note: The image asset must be set separately using setImageAsset()
    public func toRecord(
        galleryRecordID: CKRecord.ID,
        recordID: CKRecord.ID? = nil
    ) -> CKRecord {
        let id = recordID ?? CKRecord.ID(recordName: self.id)
        let record = CKRecord(recordType: Self.recordType, recordID: id)

        let galleryRef = CKRecord.Reference(
            recordID: galleryRecordID,
            action: .deleteSelf  // Delete images when gallery is deleted
        )

        record[FieldKey.gallery.rawValue] = galleryRef
        record[FieldKey.filename.rawValue] = filename
        record[FieldKey.sortOrder.rawValue] = Int64(sortOrder)
        record[FieldKey.width.rawValue] = Int64(width)
        record[FieldKey.height.rawValue] = Int64(height)
        record[FieldKey.fileSizeBytes.rawValue] = fileSizeBytes

        return record
    }

    /// Set the image asset on a record from image data
    public static func setImageAsset(
        on record: CKRecord,
        imageData: Data
    ) throws -> URL {
        // Write data to a temporary file for CKAsset
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")

        try imageData.write(to: tempFile)

        let asset = CKAsset(fileURL: tempFile)
        record[FieldKey.imageAsset.rawValue] = asset

        return tempFile
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SharedImage, rhs: SharedImage) -> Bool {
        lhs.id == rhs.id
    }
}
