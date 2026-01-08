import Foundation
import CloudKit

/// Reasons a user can report content
public enum ReportReason: String, CaseIterable, Sendable {
    case inappropriate = "Inappropriate content"
    case copyright = "Copyright violation"
    case spam = "Spam"
    case harassment = "Harassment or bullying"
    case other = "Other"
}

/// Status of a content report
public enum ReportStatus: String, Sendable {
    case pending = "pending"
    case reviewed = "reviewed"
    case actioned = "actioned"
    case dismissed = "dismissed"
}

/// A report of inappropriate or violating content
public struct ContentReport: Identifiable, Sendable {
    /// CloudKit record ID
    public let id: String

    /// The gallery being reported
    public let reportedGalleryID: String

    /// Optional: specific image being reported (nil if reporting the whole gallery)
    public let reportedImageID: String?

    /// CloudKit record ID of the user making the report
    public let reporterRecordID: String

    /// Reason for the report
    public var reason: ReportReason

    /// Additional details provided by the reporter
    public var details: String?

    /// When the report was created
    public var createdAt: Date

    /// Current status of the report
    public var status: ReportStatus

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        reportedGalleryID: String,
        reportedImageID: String? = nil,
        reporterRecordID: String,
        reason: ReportReason,
        details: String? = nil,
        createdAt: Date = Date(),
        status: ReportStatus = .pending
    ) {
        self.id = id
        self.reportedGalleryID = reportedGalleryID
        self.reportedImageID = reportedImageID
        self.reporterRecordID = reporterRecordID
        self.reason = reason
        self.details = details
        self.createdAt = createdAt
        self.status = status
    }

    // MARK: - CloudKit Record Conversion

    /// CloudKit record type name
    public static let recordType = "ContentReport"

    /// CloudKit field keys
    public enum FieldKey: String {
        case reportedGalleryID
        case reportedImageID
        case reporterRecordID
        case reason
        case details
        case createdAt
        case status
    }

    /// Initialize from a CloudKit record
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }

        self.id = record.recordID.recordName

        guard let reportedGalleryID = record[FieldKey.reportedGalleryID.rawValue] as? String,
              let reporterRecordID = record[FieldKey.reporterRecordID.rawValue] as? String,
              let reasonString = record[FieldKey.reason.rawValue] as? String,
              let reason = ReportReason(rawValue: reasonString),
              let createdAt = record[FieldKey.createdAt.rawValue] as? Date,
              let statusString = record[FieldKey.status.rawValue] as? String,
              let status = ReportStatus(rawValue: statusString)
        else {
            return nil
        }

        self.reportedGalleryID = reportedGalleryID
        self.reportedImageID = record[FieldKey.reportedImageID.rawValue] as? String
        self.reporterRecordID = reporterRecordID
        self.reason = reason
        self.details = record[FieldKey.details.rawValue] as? String
        self.createdAt = createdAt
        self.status = status
    }

    /// Convert to a CloudKit record
    public func toRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let id = recordID ?? CKRecord.ID(recordName: self.id)
        let record = CKRecord(recordType: Self.recordType, recordID: id)

        record[FieldKey.reportedGalleryID.rawValue] = reportedGalleryID
        record[FieldKey.reportedImageID.rawValue] = reportedImageID
        record[FieldKey.reporterRecordID.rawValue] = reporterRecordID
        record[FieldKey.reason.rawValue] = reason.rawValue
        record[FieldKey.details.rawValue] = details
        record[FieldKey.createdAt.rawValue] = createdAt
        record[FieldKey.status.rawValue] = status.rawValue

        return record
    }
}
