import Foundation
import CloudKit
import SwiftUI

#if canImport(SensitiveContentAnalysis)
import SensitiveContentAnalysis
#endif

/// Errors that can occur during content moderation operations
public enum ContentModerationError: LocalizedError {
    case notAuthenticated
    case reportFailed(String)
    case blockFailed(String)
    case fetchFailed(String)
    case sensitiveContentDetected
    case analysisUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed into iCloud to perform this action."
        case .reportFailed(let reason):
            return "Failed to submit report: \(reason)"
        case .blockFailed(let reason):
            return "Failed to block user: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch data: \(reason)"
        case .sensitiveContentDetected:
            return "This image contains sensitive content and cannot be uploaded."
        case .analysisUnavailable:
            return "Content analysis is not available on this device."
        }
    }
}

/// Result of content analysis
public struct ContentAnalysisResult: Sendable {
    public let isSensitive: Bool
    public let interventionLevel: InterventionLevel

    public enum InterventionLevel: Sendable {
        case none
        case mild
        case severe
    }

    public static let safe = ContentAnalysisResult(isSensitive: false, interventionLevel: .none)
}

/// Service for content moderation features
@MainActor
public class ContentModerationService: ObservableObject {

    // MARK: - Singleton

    public static let shared = ContentModerationService()

    // MARK: - CloudKit Configuration

    private static let containerIdentifier = "iCloud.com.arton.galleries"
    private let container: CKContainer
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase

    // MARK: - Published State

    @Published public var blockedUsers: [BlockedUser] = []
    @Published public var isLoading = false

    // MARK: - Initialization

    private init() {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account Helpers

    /// Check if user is authenticated with iCloud
    private func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Get the current user's record ID
    private func currentUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }

    // MARK: - Report Content

    /// Submit a report for inappropriate content
    public func reportContent(
        galleryID: String,
        imageID: String? = nil,
        reason: ReportReason,
        details: String? = nil
    ) async throws {
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw ContentModerationError.notAuthenticated
        }

        do {
            let userRecordID = try await currentUserRecordID()

            let report = ContentReport(
                reportedGalleryID: galleryID,
                reportedImageID: imageID,
                reporterRecordID: userRecordID.recordName,
                reason: reason,
                details: details
            )

            let record = report.toRecord()
            try await publicDatabase.save(record)

        } catch let error as ContentModerationError {
            throw error
        } catch {
            throw ContentModerationError.reportFailed(error.localizedDescription)
        }
    }

    // MARK: - Block Users

    /// Block a user from appearing in your Explore feed
    public func blockUser(ownerRecordID: String, ownerName: String) async throws {
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw ContentModerationError.notAuthenticated
        }

        do {
            let userRecordID = try await currentUserRecordID()

            let blockedUser = BlockedUser(
                blockerRecordID: userRecordID.recordName,
                blockedRecordID: ownerRecordID,
                blockedUserName: ownerName
            )

            // Store in private database (only visible to this user)
            let record = blockedUser.toRecord()
            try await privateDatabase.save(record)

            // Update local cache
            if !blockedUsers.contains(where: { $0.blockedRecordID == ownerRecordID }) {
                blockedUsers.append(blockedUser)
            }

        } catch let error as ContentModerationError {
            throw error
        } catch {
            throw ContentModerationError.blockFailed(error.localizedDescription)
        }
    }

    /// Unblock a previously blocked user
    public func unblockUser(_ blockedUser: BlockedUser) async throws {
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw ContentModerationError.notAuthenticated
        }

        do {
            let recordID = CKRecord.ID(recordName: blockedUser.id)
            try await privateDatabase.deleteRecord(withID: recordID)

            // Update local cache
            blockedUsers.removeAll { $0.id == blockedUser.id }

        } catch {
            throw ContentModerationError.blockFailed(error.localizedDescription)
        }
    }

    /// Fetch all blocked users for the current user
    public func fetchBlockedUsers() async throws -> [BlockedUser] {
        let status = try await checkAccountStatus()
        guard status == .available else {
            return []
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let userRecordID = try await currentUserRecordID()

            let predicate = NSPredicate(
                format: "%K == %@",
                BlockedUser.FieldKey.blockerRecordID.rawValue,
                userRecordID.recordName
            )

            let query = CKQuery(recordType: BlockedUser.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: BlockedUser.FieldKey.createdAt.rawValue, ascending: false)]

            var blocked: [BlockedUser] = []
            var cursor: CKQueryOperation.Cursor?

            repeat {
                let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

                if let existingCursor = cursor {
                    result = try await privateDatabase.records(continuingMatchFrom: existingCursor)
                } else {
                    result = try await privateDatabase.records(matching: query)
                }

                let batch = result.matchResults.compactMap { (_, recordResult) -> BlockedUser? in
                    guard case .success(let record) = recordResult else { return nil }
                    return BlockedUser(record: record)
                }

                blocked.append(contentsOf: batch)
                cursor = result.queryCursor

            } while cursor != nil

            blockedUsers = blocked
            return blocked

        } catch {
            throw ContentModerationError.fetchFailed(error.localizedDescription)
        }
    }

    /// Get set of blocked user record IDs for filtering
    public func blockedUserRecordIDs() async -> Set<String> {
        if blockedUsers.isEmpty {
            _ = try? await fetchBlockedUsers()
        }
        return Set(blockedUsers.map { $0.blockedRecordID })
    }

    /// Check if a user is blocked
    public func isUserBlocked(ownerRecordID: String) -> Bool {
        blockedUsers.contains { $0.blockedRecordID == ownerRecordID }
    }

    // MARK: - Pre-Upload Content Screening

    /// Analyze an image for sensitive content before upload
    /// Returns true if the image is safe to upload, false if it contains sensitive content
    #if os(iOS) || os(macOS)
    @available(iOS 17.0, macOS 14.0, *)
    public func analyzeImage(_ image: PlatformImage) async -> ContentAnalysisResult {
        #if canImport(SensitiveContentAnalysis)
        let analyzer = SCSensitivityAnalyzer()

        // Check if analysis is enabled by the user
        guard analyzer.analysisPolicy != .disabled else {
            // Analysis is disabled - allow upload (rely on manual moderation)
            return .safe
        }

        do {
            #if os(iOS)
            guard let cgImage = image.cgImage else {
                return .safe
            }
            let result = try await analyzer.analyzeImage(cgImage)
            #elseif os(macOS)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return .safe
            }
            let result = try await analyzer.analyzeImage(cgImage)
            #endif

            // SCSensitivityAnalysis only provides isSensitive boolean
            // We treat all sensitive content the same way
            let interventionLevel: ContentAnalysisResult.InterventionLevel = result.isSensitive ? .severe : .none

            return ContentAnalysisResult(
                isSensitive: result.isSensitive,
                interventionLevel: interventionLevel
            )
        } catch {
            // Analysis failed - allow upload (rely on manual moderation)
            return .safe
        }
        #else
        return .safe
        #endif
    }
    #endif

    /// Check if content analysis is available on this device
    #if os(iOS) || os(macOS)
    @available(iOS 17.0, macOS 14.0, *)
    public var isContentAnalysisAvailable: Bool {
        #if canImport(SensitiveContentAnalysis)
        let analyzer = SCSensitivityAnalyzer()
        return analyzer.analysisPolicy != .disabled
        #else
        return false
        #endif
    }
    #endif

    /// Analyze multiple images and return indices of sensitive ones
    #if os(iOS) || os(macOS)
    @available(iOS 17.0, macOS 14.0, *)
    public func analyzeImages(_ images: [PlatformImage]) async -> [Int] {
        var sensitiveIndices: [Int] = []

        for (index, image) in images.enumerated() {
            let result = await analyzeImage(image)
            if result.isSensitive {
                sensitiveIndices.append(index)
            }
        }

        return sensitiveIndices
    }
    #endif

    // MARK: - App Information

    /// Contact email for beta feedback and support
    public static let supportEmail = "arton@tomabel.org"

    /// Terms of Service URL
    public static let termsOfServiceURL = URL(string: "https://arton.app/terms")!

    /// Privacy Policy URL
    public static let privacyPolicyURL = URL(string: "https://arton.app/privacy")!

    /// Community Guidelines URL
    public static let communityGuidelinesURL = URL(string: "https://arton.app/guidelines")!
}
