import Foundation
import CloudKit
import SwiftUI

/// View model for the Explore tab showing public shared galleries
@MainActor
public class ExploreViewModel: ObservableObject {
    @Published public var galleries: [SharedGallery] = []
    @Published public var isLoading = false
    @Published public var isLoadingMore = false
    @Published public var hasMore = true
    @Published public var errorMessage: String?

    private var cursor: CKQueryOperation.Cursor?
    private let sharingService = CloudKitSharingService.shared
    private let moderationService = ContentModerationService.shared

    public init() {}

    /// Filter galleries by removing blocked users
    private func filterBlockedUsers(_ galleries: [SharedGallery]) async -> [SharedGallery] {
        let blockedIDs = await moderationService.blockedUserRecordIDs()
        guard !blockedIDs.isEmpty else { return galleries }
        return galleries.filter { !blockedIDs.contains($0.ownerRecordID) }
    }

    /// Load the initial batch of public galleries
    public func loadInitial() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await sharingService.fetchPublicGalleries(limit: 20)
            galleries = await filterBlockedUsers(result.galleries)
            cursor = result.cursor
            hasMore = result.cursor != nil
        } catch {
            errorMessage = error.localizedDescription
            galleries = []
        }

        isLoading = false
    }

    /// Load more galleries (pagination)
    public func loadMore() {
        guard !isLoading, !isLoadingMore, hasMore else { return }

        Task {
            isLoadingMore = true

            do {
                let result = try await sharingService.fetchPublicGalleries(cursor: cursor, limit: 20)
                let filtered = await filterBlockedUsers(result.galleries)
                galleries.append(contentsOf: filtered)
                cursor = result.cursor
                hasMore = result.cursor != nil
            } catch {
                // Don't clear existing galleries on pagination error
                errorMessage = error.localizedDescription
            }

            isLoadingMore = false
        }
    }

    /// Refresh the gallery list
    public func refresh() async {
        cursor = nil
        await loadInitial()
    }
}
