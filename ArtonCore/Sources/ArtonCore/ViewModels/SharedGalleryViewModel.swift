import Foundation
import CloudKit
import SwiftUI

/// View model for viewing a shared gallery's images
@MainActor
public class SharedGalleryViewModel: ObservableObject {
    public let gallery: SharedGallery

    @Published public var images: [SharedImage] = []
    @Published public var isLoading = false
    @Published public var isLoadingMore = false
    @Published public var hasMore = true
    @Published public var errorMessage: String?

    /// Cache of downloaded image data
    @Published public var imageDataCache: [String: Data] = [:]

    /// Currently loading image IDs
    @Published public var loadingImageIDs: Set<String> = []

    private var cursor: CKQueryOperation.Cursor?
    private let sharingService = CloudKitSharingService.shared

    public init(gallery: SharedGallery) {
        self.gallery = gallery
    }

    /// Load the initial batch of images
    public func loadImages() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await sharingService.fetchImages(for: gallery, limit: 50)
            images = result.images
            cursor = result.cursor
            hasMore = result.cursor != nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more images (pagination)
    public func loadMoreImages() {
        guard !isLoading, !isLoadingMore, hasMore else { return }

        Task {
            isLoadingMore = true

            do {
                let result = try await sharingService.fetchImages(for: gallery, cursor: cursor, limit: 50)
                images.append(contentsOf: result.images)
                cursor = result.cursor
                hasMore = result.cursor != nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoadingMore = false
        }
    }

    /// Download image data for a specific image
    public func loadImageData(for image: SharedImage) async -> Data? {
        // Check cache first
        if let cachedData = imageDataCache[image.id] {
            return cachedData
        }

        // Check if already loading
        guard !loadingImageIDs.contains(image.id) else { return nil }

        loadingImageIDs.insert(image.id)

        do {
            let data = try await sharingService.downloadImageData(for: image)
            imageDataCache[image.id] = data
            loadingImageIDs.remove(image.id)
            return data
        } catch {
            loadingImageIDs.remove(image.id)
            return nil
        }
    }

    /// Clear the image cache
    public func clearCache() {
        imageDataCache.removeAll()
    }
}
