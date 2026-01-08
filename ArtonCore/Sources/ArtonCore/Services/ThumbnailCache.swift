import Foundation
import CryptoKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A cache for thumbnail images stored on disk with an in-memory layer for recently accessed thumbnails.
public actor ThumbnailCache {

    /// Shared singleton instance
    public static let shared = ThumbnailCache()

    // MARK: - Private Properties

    /// In-memory cache for recently accessed thumbnails
    private var memoryCache: [String: PlatformImage] = [:]

    /// Maximum number of thumbnails to keep in memory
    private let maxMemoryCacheSize = 50

    /// Order of keys for LRU eviction
    private var memoryCacheOrder: [String] = []

    /// JPEG compression quality for cached thumbnails
    private let compressionQuality: CGFloat = 0.8

    /// Name of the thumbnails subdirectory in Caches
    private let thumbnailsDirectoryName = "Thumbnails"

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Get or generate a thumbnail for an image at the specified URL.
    /// - Parameters:
    ///   - imageURL: The URL of the source image
    ///   - size: The maximum dimension (width or height) for the thumbnail
    /// - Returns: A thumbnail image, or nil if generation fails
    public func thumbnail(for imageURL: URL, size: CGFloat) async -> PlatformImage? {
        let cacheKey = generateCacheKey(for: imageURL, size: size)

        // Check in-memory cache first
        if let cached = memoryCache[cacheKey] {
            updateMemoryCacheOrder(for: cacheKey)
            return cached
        }

        // Check disk cache
        let cachedFileURL = cachedThumbnailURL(for: cacheKey)

        if let thumbnail = loadFromDiskCache(at: cachedFileURL, sourceURL: imageURL) {
            addToMemoryCache(thumbnail, for: cacheKey)
            return thumbnail
        }

        // Generate new thumbnail
        guard let thumbnail = ImageUtilities.generateThumbnail(from: imageURL, maxSize: size) else {
            return nil
        }

        // Save to disk cache
        saveToDiskCache(thumbnail, at: cachedFileURL)

        // Add to memory cache
        addToMemoryCache(thumbnail, for: cacheKey)

        return thumbnail
    }

    /// Clear all cached thumbnails from both memory and disk.
    public func clearCache() async {
        // Clear memory cache
        memoryCache.removeAll()
        memoryCacheOrder.removeAll()

        // Clear disk cache by deleting the entire Thumbnails directory
        guard let thumbnailsDirectory = thumbnailsDirectoryURL() else { return }

        try? FileManager.default.removeItem(at: thumbnailsDirectory)
    }

    /// Invalidate the cached thumbnail for a specific image URL.
    /// - Parameter imageURL: The URL of the source image whose thumbnail should be invalidated
    public func invalidate(imageURL: URL) async {
        // We need to invalidate all sizes for this image URL
        // Since we don't track all sizes, we'll clear any matching keys from memory
        // and delete files that match the URL pattern

        let urlPath = imageURL.path

        // Remove from memory cache - check all keys that might match this URL
        let keysToRemove = memoryCache.keys.filter { key in
            // The key is a hash, so we need to regenerate possible keys
            // For simplicity, we'll check common sizes
            for size in [100, 150, 200, 250, 300, 400, 500] as [CGFloat] {
                if generateCacheKey(for: imageURL, size: size) == key {
                    return true
                }
            }
            return false
        }

        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
            memoryCacheOrder.removeAll { $0 == key }
        }

        // For disk cache, delete any files matching this image
        // Since we hash the full path, we delete files for all common sizes
        guard let thumbnailsDirectory = thumbnailsDirectoryURL() else { return }

        for size in [100, 150, 200, 250, 300, 400, 500] as [CGFloat] {
            let cacheKey = generateCacheKey(for: imageURL, size: size)
            let fileURL = thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Methods

    /// Generate a cache key from the image URL and size using SHA256.
    private func generateCacheKey(for url: URL, size: CGFloat) -> String {
        let input = "\(url.path)_\(Int(size))"
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get the URL for the Thumbnails cache directory.
    private func thumbnailsDirectoryURL() -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let thumbnailsDirectory = cachesDirectory.appendingPathComponent(thumbnailsDirectoryName)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: thumbnailsDirectory.path) {
            try? FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        }

        return thumbnailsDirectory
    }

    /// Get the URL for a cached thumbnail file.
    private func cachedThumbnailURL(for cacheKey: String) -> URL? {
        guard let thumbnailsDirectory = thumbnailsDirectoryURL() else { return nil }
        return thumbnailsDirectory.appendingPathComponent("\(cacheKey).jpg")
    }

    /// Load a thumbnail from disk cache if it exists and is fresh.
    private func loadFromDiskCache(at cacheURL: URL?, sourceURL: URL) -> PlatformImage? {
        guard let cacheURL = cacheURL else { return nil }

        let fileManager = FileManager.default

        // Check if cached file exists
        guard fileManager.fileExists(atPath: cacheURL.path) else { return nil }

        // Check modification dates
        guard let cacheAttributes = try? fileManager.attributesOfItem(atPath: cacheURL.path),
              let sourceAttributes = try? fileManager.attributesOfItem(atPath: sourceURL.path),
              let cacheDate = cacheAttributes[.modificationDate] as? Date,
              let sourceDate = sourceAttributes[.modificationDate] as? Date else {
            return nil
        }

        // Cache is stale if source is newer
        guard cacheDate >= sourceDate else {
            // Delete stale cache
            try? fileManager.removeItem(at: cacheURL)
            return nil
        }

        // Load from disk
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }

        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
    }

    /// Save a thumbnail to disk cache.
    private func saveToDiskCache(_ image: PlatformImage, at cacheURL: URL?) {
        guard let cacheURL = cacheURL else { return }

        guard let jpegData = jpegData(from: image) else { return }

        try? jpegData.write(to: cacheURL, options: .atomic)
    }

    /// Convert a platform image to JPEG data.
    private func jpegData(from image: PlatformImage) -> Data? {
        #if canImport(UIKit)
        return image.jpegData(compressionQuality: compressionQuality)
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #endif
    }

    /// Add a thumbnail to the in-memory cache with LRU eviction.
    private func addToMemoryCache(_ image: PlatformImage, for key: String) {
        // Remove existing entry if present
        if memoryCache[key] != nil {
            memoryCacheOrder.removeAll { $0 == key }
        }

        // Evict oldest if at capacity
        while memoryCacheOrder.count >= maxMemoryCacheSize {
            if let oldestKey = memoryCacheOrder.first {
                memoryCache.removeValue(forKey: oldestKey)
                memoryCacheOrder.removeFirst()
            }
        }

        // Add new entry
        memoryCache[key] = image
        memoryCacheOrder.append(key)
    }

    /// Update the access order for LRU tracking.
    private func updateMemoryCacheOrder(for key: String) {
        memoryCacheOrder.removeAll { $0 == key }
        memoryCacheOrder.append(key)
    }
}
