import Foundation
import CloudKit

/// Represents a user that has been blocked by another user
public struct BlockedUser: Identifiable, Sendable, Hashable {
    /// CloudKit record ID
    public let id: String

    /// CloudKit record ID of the user who blocked
    public let blockerRecordID: String

    /// CloudKit record ID of the blocked user
    public let blockedRecordID: String

    /// Display name of the blocked user (for UI)
    public var blockedUserName: String

    /// When the block was created
    public var createdAt: Date

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        blockerRecordID: String,
        blockedRecordID: String,
        blockedUserName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.blockerRecordID = blockerRecordID
        self.blockedRecordID = blockedRecordID
        self.blockedUserName = blockedUserName
        self.createdAt = createdAt
    }

    // MARK: - CloudKit Record Conversion

    /// CloudKit record type name
    public static let recordType = "BlockedUser"

    /// CloudKit field keys
    public enum FieldKey: String {
        case blockerRecordID
        case blockedRecordID
        case blockedUserName
        case createdAt
    }

    /// Initialize from a CloudKit record
    public init?(record: CKRecord) {
        guard record.recordType == Self.recordType else { return nil }

        self.id = record.recordID.recordName

        guard let blockerRecordID = record[FieldKey.blockerRecordID.rawValue] as? String,
              let blockedRecordID = record[FieldKey.blockedRecordID.rawValue] as? String,
              let blockedUserName = record[FieldKey.blockedUserName.rawValue] as? String,
              let createdAt = record[FieldKey.createdAt.rawValue] as? Date
        else {
            return nil
        }

        self.blockerRecordID = blockerRecordID
        self.blockedRecordID = blockedRecordID
        self.blockedUserName = blockedUserName
        self.createdAt = createdAt
    }

    /// Convert to a CloudKit record for the private database
    public func toRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let id = recordID ?? CKRecord.ID(recordName: self.id)
        let record = CKRecord(recordType: Self.recordType, recordID: id)

        record[FieldKey.blockerRecordID.rawValue] = blockerRecordID
        record[FieldKey.blockedRecordID.rawValue] = blockedRecordID
        record[FieldKey.blockedUserName.rawValue] = blockedUserName
        record[FieldKey.createdAt.rawValue] = createdAt

        return record
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: BlockedUser, rhs: BlockedUser) -> Bool {
        lhs.id == rhs.id
    }
}
