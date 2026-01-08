import Foundation
import Combine

/// Main service for managing galleries and their images
///
/// This class coordinates between iCloudManager (folder operations) and
/// GallerySettingsStore (per-gallery settings) to provide a unified API
/// for gallery management across all platforms.
@MainActor
public class GalleryManager: ObservableObject {
    /// Shared instance for app-wide gallery management
    public static let shared = GalleryManager()

    // MARK: - Published Properties

    /// All loaded galleries, sorted alphabetically by name
    @Published public private(set) var galleries: [Gallery] = []

    /// Whether galleries are currently being loaded
    @Published public private(set) var isLoading: Bool = false

    /// Most recent error encountered, if any
    @Published public private(set) var error: ArtonError?

    // MARK: - Dependencies

    private let iCloudManager: iCloudManager
    private let settingsStore: GallerySettingsStore

    // MARK: - Initialization

    public init(
        iCloudManager: iCloudManager = .shared,
        settingsStore: GallerySettingsStore = .shared
    ) {
        self.iCloudManager = iCloudManager
        self.settingsStore = settingsStore
    }

    // MARK: - Gallery Loading

    /// Load all galleries from iCloud
    ///
    /// This method fetches all gallery folders from iCloud Drive and creates
    /// Gallery objects for each one. The galleries array is updated on completion.
    public func loadGalleries() async {
        isLoading = true
        error = nil

        do {
            let folderURLs = try await iCloudManager.listGalleryFolders()

            var loadedGalleries: [Gallery] = []
            for url in folderURLs {
                let gallery = await createGallery(from: url)
                loadedGalleries.append(gallery)
            }

            // Sort alphabetically by name
            galleries = loadedGalleries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch let artonError as ArtonError {
            error = artonError
        } catch {
            self.error = .fileOperationFailed(operation: "loadGalleries", reason: error.localizedDescription)
        }

        isLoading = false
    }

    /// Create a Gallery object from a folder URL
    private func createGallery(from folderURL: URL) async -> Gallery {
        let name = folderURL.lastPathComponent

        // Get folder attributes for dates
        let fileManager = FileManager.default
        var createdAt = Date()
        var modifiedAt = Date()

        if let attributes = try? fileManager.attributesOfItem(atPath: folderURL.path) {
            createdAt = attributes[.creationDate] as? Date ?? Date()
            modifiedAt = attributes[.modificationDate] as? Date ?? Date()
        }

        // Count images (cached for performance)
        let imageCount = countImages(in: folderURL)

        // Generate stable ID from folder path
        let id = stableID(for: folderURL)

        return Gallery(
            id: id,
            name: name,
            folderURL: folderURL,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            cachedImageCount: imageCount
        )
    }

    /// Generate a stable UUID from a folder URL
    private func stableID(for url: URL) -> UUID {
        // Use a hash of the path to generate a consistent UUID
        let path = url.path
        var hasher = Hasher()
        hasher.combine(path)
        let hash = hasher.finalize()

        // Create UUID from hash bytes
        var bytes = withUnsafeBytes(of: hash) { Array($0) }
        // Pad to 16 bytes if needed
        while bytes.count < 16 {
            bytes.append(0)
        }

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Count supported image files in a directory
    private func countImages(in folderURL: URL) -> Int {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        return contents.filter { ArtworkImage.isSupportedImage(url: $0) }.count
    }

    // MARK: - Gallery CRUD

    /// Create a new gallery with the given name
    ///
    /// - Parameter name: The name for the new gallery
    /// - Returns: The newly created Gallery
    /// - Throws: ArtonError if creation fails
    @discardableResult
    public func createGallery(named name: String) async throws -> Gallery {
        let folderURL = try await iCloudManager.createGalleryFolder(named: name)

        // Create default settings for the new gallery
        try await settingsStore.saveSettings(.default, to: folderURL)

        let gallery = await createGallery(from: folderURL)

        // Add to galleries list and re-sort
        var updatedGalleries = galleries
        updatedGalleries.append(gallery)
        galleries = updatedGalleries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return gallery
    }

    /// Delete a gallery and all its contents
    ///
    /// - Parameter gallery: The gallery to delete
    /// - Throws: ArtonError if deletion fails
    public func deleteGallery(_ gallery: Gallery) async throws {
        try await iCloudManager.deleteGalleryFolder(at: gallery.folderURL)

        // Remove from local list
        galleries.removeAll { $0.id == gallery.id }
    }

    /// Rename a gallery
    ///
    /// - Parameters:
    ///   - gallery: The gallery to rename
    ///   - newName: The new name for the gallery
    /// - Throws: ArtonError if renaming fails
    public func renameGallery(_ gallery: Gallery, to newName: String) async throws {
        let newURL = try await iCloudManager.renameGalleryFolder(at: gallery.folderURL, to: newName)

        // Update local gallery object
        if let index = galleries.firstIndex(where: { $0.id == gallery.id }) {
            var updatedGallery = galleries[index]
            updatedGallery = Gallery(
                id: updatedGallery.id,
                name: newName,
                folderURL: newURL,
                createdAt: updatedGallery.createdAt,
                modifiedAt: Date(),
                cachedImageCount: updatedGallery.cachedImageCount
            )
            galleries[index] = updatedGallery

            // Re-sort after rename
            galleries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: - Image Loading

    /// Load all images for a specific gallery
    ///
    /// - Parameter gallery: The gallery to load images from
    /// - Returns: Array of ArtworkImage objects, sorted by filename
    /// - Throws: ArtonError if loading fails
    public func loadImages(for gallery: Gallery) async throws -> [ArtworkImage] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: gallery.folderURL.path) else {
            throw ArtonError.galleryNotFound(name: gallery.name)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: gallery.folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        )

        var images: [ArtworkImage] = []

        for url in contents {
            guard ArtworkImage.isSupportedImage(url: url) else { continue }

            let resourceValues = try? url.resourceValues(forKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .ubiquitousItemDownloadingStatusKey
            ])

            // Check if file is downloaded (for iCloud files)
            let downloadStatus = resourceValues?.ubiquitousItemDownloadingStatus
            let isDownloaded = downloadStatus == nil || downloadStatus == .current

            // Get file size
            let fileSize = resourceValues?.fileSize.map { Int64($0) }

            // Get image dimensions without loading full image
            let dimensions = ImageUtilities.imageDimensions(at: url)

            let image = ArtworkImage(
                fileURL: url,
                galleryURL: gallery.folderURL,
                isDownloaded: isDownloaded,
                fileSizeBytes: fileSize,
                dimensions: dimensions
            )

            images.append(image)
        }

        // Sort by filename (case-insensitive)
        return images.sorted { $0.sortKey < $1.sortKey }
    }

    /// Get the poster image for a gallery (first image alphabetically)
    ///
    /// - Parameter gallery: The gallery to get the poster for
    /// - Returns: The first ArtworkImage, or nil if gallery is empty
    public func posterImage(for gallery: Gallery) async -> ArtworkImage? {
        do {
            let images = try await loadImages(for: gallery)
            return images.first
        } catch {
            return nil
        }
    }

    // MARK: - Settings

    /// Load settings for a gallery
    ///
    /// - Parameter gallery: The gallery to load settings for
    /// - Returns: The gallery's settings
    public func loadSettings(for gallery: Gallery) async throws -> GallerySettings {
        try await settingsStore.loadSettings(for: gallery.folderURL)
    }

    /// Save settings for a gallery
    ///
    /// - Parameters:
    ///   - settings: The settings to save
    ///   - gallery: The gallery to save settings for
    public func saveSettings(_ settings: GallerySettings, for gallery: Gallery) async throws {
        try await settingsStore.saveSettings(settings, to: gallery.folderURL)
    }

    // MARK: - Image Management

    /// Add images to a gallery by copying from source URLs
    ///
    /// - Parameters:
    ///   - urls: Source URLs of images to add
    ///   - gallery: The destination gallery
    /// - Returns: Array of successfully added ArtworkImage objects
    @discardableResult
    public func addImages(from urls: [URL], to gallery: Gallery) async throws -> [ArtworkImage] {
        let fileManager = FileManager.default
        var addedImages: [ArtworkImage] = []

        for sourceURL in urls {
            guard ArtworkImage.isSupportedImage(url: sourceURL) else { continue }

            let filename = sourceURL.lastPathComponent
            var destinationURL = gallery.folderURL.appendingPathComponent(filename)

            // Handle duplicate filenames
            var counter = 1
            let nameWithoutExtension = (filename as NSString).deletingPathExtension
            let fileExtension = (filename as NSString).pathExtension

            while fileManager.fileExists(atPath: destinationURL.path) {
                let newName = "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
                destinationURL = gallery.folderURL.appendingPathComponent(newName)
                counter += 1
            }

            do {
                // Start accessing security-scoped resource if needed
                let accessing = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                try fileManager.copyItem(at: sourceURL, to: destinationURL)

                let image = ArtworkImage(
                    fileURL: destinationURL,
                    galleryURL: gallery.folderURL,
                    isDownloaded: true,
                    fileSizeBytes: nil,
                    dimensions: ImageUtilities.imageDimensions(at: destinationURL)
                )
                addedImages.append(image)
            } catch {
                // Continue with other images if one fails
                continue
            }
        }

        // Update cached image count
        if let index = galleries.firstIndex(where: { $0.id == gallery.id }) {
            var updatedGallery = galleries[index]
            let newCount = (updatedGallery.cachedImageCount ?? 0) + addedImages.count
            updatedGallery = Gallery(
                id: updatedGallery.id,
                name: updatedGallery.name,
                folderURL: updatedGallery.folderURL,
                createdAt: updatedGallery.createdAt,
                modifiedAt: Date(),
                cachedImageCount: newCount
            )
            galleries[index] = updatedGallery
        }

        return addedImages
    }

    /// Delete an image from a gallery
    ///
    /// - Parameters:
    ///   - image: The image to delete
    ///   - gallery: The gallery containing the image
    public func deleteImage(_ image: ArtworkImage, from gallery: Gallery) async throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: image.fileURL.path) else {
            throw ArtonError.imageNotFound(filename: image.filename)
        }

        try fileManager.removeItem(at: image.fileURL)

        // Update cached image count
        if let index = galleries.firstIndex(where: { $0.id == gallery.id }) {
            var updatedGallery = galleries[index]
            let newCount = max(0, (updatedGallery.cachedImageCount ?? 1) - 1)
            updatedGallery = Gallery(
                id: updatedGallery.id,
                name: updatedGallery.name,
                folderURL: updatedGallery.folderURL,
                createdAt: updatedGallery.createdAt,
                modifiedAt: Date(),
                cachedImageCount: newCount
            )
            galleries[index] = updatedGallery
        }

        // Invalidate thumbnail cache
        await ThumbnailCache.shared.invalidate(imageURL: image.fileURL)
    }
}
