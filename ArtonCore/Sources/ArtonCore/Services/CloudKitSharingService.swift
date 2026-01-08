import Foundation
import CloudKit
import SwiftUI

/// Errors that can occur during CloudKit sharing operations
public enum CloudKitSharingError: LocalizedError {
    case notAuthenticated
    case containerUnavailable
    case uploadFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case imageCompressionFailed
    case imageTooLarge
    case galleryNotFound
    case networkUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed into iCloud to share galleries."
        case .containerUnavailable:
            return "iCloud container is not available."
        case .uploadFailed(let reason):
            return "Failed to upload: \(reason)"
        case .fetchFailed(let reason):
            return "Failed to fetch: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete: \(reason)"
        case .imageCompressionFailed:
            return "Failed to compress image for upload."
        case .imageTooLarge:
            return "Image is too large to upload (max 256MB)."
        case .galleryNotFound:
            return "Gallery not found."
        case .networkUnavailable:
            return "Network is not available."
        }
    }
}

/// Service for sharing galleries via CloudKit
@MainActor
public class CloudKitSharingService: ObservableObject {

    // MARK: - Singleton

    public static let shared = CloudKitSharingService()

    // MARK: - CloudKit Configuration

    private static let containerIdentifier = "iCloud.com.arton.galleries"
    private let container: CKContainer
    private let publicDatabase: CKDatabase

    // MARK: - Published State

    @Published public var isUploading = false
    @Published public var uploadProgress: Double = 0
    @Published public var currentUploadStatus: String = ""

    // MARK: - Constants

    /// Maximum image dimension (pixels) before compression
    public static let maxImageDimension: CGFloat = 2048

    /// JPEG compression quality
    public static let jpegQuality: CGFloat = 0.8

    /// Poster image size
    public static let posterSize: CGFloat = 400

    /// Batch size for uploading images
    public static let uploadBatchSize = 10

    // MARK: - Initialization

    private init() {
        self.container = CKContainer(identifier: Self.containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase
    }

    // MARK: - Account Status

    /// Check if user is authenticated with iCloud
    public func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Get the current user's record ID
    public func currentUserRecordID() async throws -> CKRecord.ID {
        try await container.userRecordID()
    }

    /// Get the current user's display name
    public func currentUserName() async throws -> String {
        let userID = try await currentUserRecordID()

        do {
            let identity = try await container.userIdentity(forUserRecordID: userID)
            if let nameComponents = identity?.nameComponents {
                let formatter = PersonNameComponentsFormatter()
                formatter.style = .default
                return formatter.string(from: nameComponents)
            }
        } catch {
            // User may not have granted name access
        }

        return "Anonymous"
    }

    // MARK: - Share Gallery

    /// Upload a gallery to the public CloudKit database
    public func shareGallery(
        _ gallery: Gallery,
        images: [ArtworkImage],
        description: String?,
        isPublic: Bool,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> SharedGallery {
        // Check account status
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitSharingError.notAuthenticated
        }

        isUploading = true
        uploadProgress = 0
        currentUploadStatus = "Preparing..."

        defer {
            isUploading = false
        }

        do {
            // Get user info
            let userRecordID = try await currentUserRecordID()
            let userName = try await currentUserName()

            // Create gallery record ID
            let galleryRecordID = CKRecord.ID(recordName: UUID().uuidString)

            // Generate poster image
            currentUploadStatus = "Creating poster..."
            progressHandler?(0.05, currentUploadStatus)

            let posterData = await generatePosterImage(from: images.first)

            // Create SharedGallery
            let sharedGallery = SharedGallery(
                id: galleryRecordID.recordName,
                galleryID: gallery.id,
                name: gallery.name,
                description: description,
                ownerName: userName,
                ownerRecordID: userRecordID.recordName,
                imageCount: images.count,
                posterImageData: posterData,
                isPublic: isPublic
            )

            // Save gallery record
            currentUploadStatus = "Creating gallery..."
            uploadProgress = 0.1
            progressHandler?(0.1, currentUploadStatus)

            let galleryRecord = sharedGallery.toRecord(recordID: galleryRecordID)
            try await publicDatabase.save(galleryRecord)

            // Upload images in batches
            let totalImages = images.count
            var uploadedCount = 0

            for batchStart in stride(from: 0, to: images.count, by: Self.uploadBatchSize) {
                let batchEnd = min(batchStart + Self.uploadBatchSize, images.count)
                let batch = Array(images[batchStart..<batchEnd])

                currentUploadStatus = "Uploading images \(uploadedCount + 1)-\(uploadedCount + batch.count) of \(totalImages)..."

                try await uploadImageBatch(
                    batch,
                    galleryRecordID: galleryRecordID,
                    startingIndex: batchStart
                )

                uploadedCount += batch.count
                let progress = 0.1 + (Double(uploadedCount) / Double(totalImages)) * 0.9
                uploadProgress = progress
                progressHandler?(progress, currentUploadStatus)
            }

            currentUploadStatus = "Complete!"
            uploadProgress = 1.0
            progressHandler?(1.0, currentUploadStatus)

            return sharedGallery

        } catch let error as CloudKitSharingError {
            throw error
        } catch {
            throw CloudKitSharingError.uploadFailed(error.localizedDescription)
        }
    }

    /// Upload a batch of images
    private func uploadImageBatch(
        _ images: [ArtworkImage],
        galleryRecordID: CKRecord.ID,
        startingIndex: Int
    ) async throws {
        var tempFiles: [URL] = []

        defer {
            // Clean up temp files
            for url in tempFiles {
                try? FileManager.default.removeItem(at: url)
            }
        }

        var records: [CKRecord] = []

        for (index, image) in images.enumerated() {
            // Load and compress image
            guard let imageData = try? await loadAndCompressImage(at: image.fileURL) else {
                continue // Skip failed images
            }

            let dimensions = imageDimensions(for: image)

            let sharedImage = SharedImage(
                id: UUID().uuidString,
                galleryRecordID: galleryRecordID.recordName,
                filename: image.filename,
                sortOrder: startingIndex + index,
                width: Int(dimensions.width),
                height: Int(dimensions.height),
                fileSizeBytes: Int64(imageData.count)
            )

            let record = sharedImage.toRecord(galleryRecordID: galleryRecordID)

            // Add image asset
            let tempFile = try SharedImage.setImageAsset(on: record, imageData: imageData)
            tempFiles.append(tempFile)

            records.append(record)
        }

        // Save batch
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys

        _ = try await publicDatabase.modifyRecords(saving: records, deleting: [])
    }

    // MARK: - Unshare Gallery

    /// Remove a shared gallery from CloudKit
    public func unshareGallery(_ sharedGallery: SharedGallery) async throws {
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitSharingError.notAuthenticated
        }

        do {
            // First, delete all images (they should cascade, but be explicit)
            let imageRecordIDs = try await fetchImageRecordIDs(for: sharedGallery)

            if !imageRecordIDs.isEmpty {
                _ = try await publicDatabase.modifyRecords(saving: [], deleting: imageRecordIDs)
            }

            // Delete the gallery record
            let galleryRecordID = CKRecord.ID(recordName: sharedGallery.id)
            try await publicDatabase.deleteRecord(withID: galleryRecordID)

        } catch {
            throw CloudKitSharingError.deleteFailed(error.localizedDescription)
        }
    }

    /// Fetch all image record IDs for a gallery (for deletion)
    private func fetchImageRecordIDs(for gallery: SharedGallery) async throws -> [CKRecord.ID] {
        let galleryRecordID = CKRecord.ID(recordName: gallery.id)
        let reference = CKRecord.Reference(recordID: galleryRecordID, action: .none)

        let predicate = NSPredicate(format: "%K == %@", SharedImage.FieldKey.gallery.rawValue, reference)
        let query = CKQuery(recordType: SharedImage.recordType, predicate: predicate)

        var recordIDs: [CKRecord.ID] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

            if let existingCursor = cursor {
                result = try await publicDatabase.records(continuingMatchFrom: existingCursor)
            } else {
                result = try await publicDatabase.records(matching: query)
            }

            recordIDs.append(contentsOf: result.matchResults.map { $0.0 })
            cursor = result.queryCursor

        } while cursor != nil

        return recordIDs
    }

    // MARK: - Fetch Public Galleries

    /// Fetch public galleries for the Explore tab
    public func fetchPublicGalleries(
        cursor: CKQueryOperation.Cursor? = nil,
        limit: Int = 20
    ) async throws -> (galleries: [SharedGallery], cursor: CKQueryOperation.Cursor?) {
        let predicate = NSPredicate(format: "%K == %d", SharedGallery.FieldKey.isPublic.rawValue, 1)
        let query = CKQuery(recordType: SharedGallery.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: SharedGallery.FieldKey.createdAt.rawValue, ascending: false)]

        let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

        if let existingCursor = cursor {
            result = try await publicDatabase.records(
                continuingMatchFrom: existingCursor,
                desiredKeys: nil,
                resultsLimit: limit
            )
        } else {
            result = try await publicDatabase.records(
                matching: query,
                desiredKeys: nil,
                resultsLimit: limit
            )
        }

        let galleries = result.matchResults.compactMap { (_, recordResult) -> SharedGallery? in
            guard case .success(let record) = recordResult else { return nil }
            return SharedGallery(record: record)
        }

        return (galleries, result.queryCursor)
    }

    /// Fetch a specific shared gallery by ID
    public func fetchGallery(id: String) async throws -> SharedGallery? {
        let recordID = CKRecord.ID(recordName: id)

        do {
            let record = try await publicDatabase.record(for: recordID)
            return SharedGallery(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw CloudKitSharingError.fetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Images

    /// Fetch images for a shared gallery
    public func fetchImages(
        for gallery: SharedGallery,
        cursor: CKQueryOperation.Cursor? = nil,
        limit: Int = 50
    ) async throws -> (images: [SharedImage], cursor: CKQueryOperation.Cursor?) {
        let galleryRecordID = CKRecord.ID(recordName: gallery.id)
        let reference = CKRecord.Reference(recordID: galleryRecordID, action: .none)

        let predicate = NSPredicate(format: "%K == %@", SharedImage.FieldKey.gallery.rawValue, reference)
        let query = CKQuery(recordType: SharedImage.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: SharedImage.FieldKey.sortOrder.rawValue, ascending: true)]

        let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

        if let existingCursor = cursor {
            result = try await publicDatabase.records(
                continuingMatchFrom: existingCursor,
                desiredKeys: nil,
                resultsLimit: limit
            )
        } else {
            result = try await publicDatabase.records(
                matching: query,
                desiredKeys: nil,
                resultsLimit: limit
            )
        }

        let images = result.matchResults.compactMap { (_, recordResult) -> SharedImage? in
            guard case .success(let record) = recordResult else { return nil }
            return SharedImage(record: record)
        }

        return (images, result.queryCursor)
    }

    /// Download image data for a shared image
    public func downloadImageData(for sharedImage: SharedImage) async throws -> Data {
        let recordID = CKRecord.ID(recordName: sharedImage.id)
        let record = try await publicDatabase.record(for: recordID)

        guard let asset = record[SharedImage.FieldKey.imageAsset.rawValue] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw CloudKitSharingError.fetchFailed("Image asset not found")
        }

        return try Data(contentsOf: fileURL)
    }

    // MARK: - My Shared Galleries

    /// Fetch galleries shared by the current user
    public func fetchMySharedGalleries() async throws -> [SharedGallery] {
        let status = try await checkAccountStatus()
        guard status == .available else {
            throw CloudKitSharingError.notAuthenticated
        }

        let userRecordID = try await currentUserRecordID()
        let predicate = NSPredicate(
            format: "%K == %@",
            SharedGallery.FieldKey.ownerRecordID.rawValue,
            userRecordID.recordName
        )

        let query = CKQuery(recordType: SharedGallery.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: SharedGallery.FieldKey.updatedAt.rawValue, ascending: false)]

        var galleries: [SharedGallery] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

            if let existingCursor = cursor {
                result = try await publicDatabase.records(continuingMatchFrom: existingCursor)
            } else {
                result = try await publicDatabase.records(matching: query)
            }

            let batch = result.matchResults.compactMap { (_, recordResult) -> SharedGallery? in
                guard case .success(let record) = recordResult else { return nil }
                return SharedGallery(record: record)
            }

            galleries.append(contentsOf: batch)
            cursor = result.queryCursor

        } while cursor != nil

        return galleries
    }

    // MARK: - Image Processing Helpers

    /// Load and compress an image for upload
    private func loadAndCompressImage(at url: URL) async throws -> Data {
        // Load image data
        let originalData = try Data(contentsOf: url)

        #if canImport(UIKit)
        guard let image = UIImage(data: originalData) else {
            throw CloudKitSharingError.imageCompressionFailed
        }

        // Resize if needed
        let resizedImage = resizeImage(image, maxDimension: Self.maxImageDimension)

        // Compress to JPEG
        guard let compressedData = resizedImage.jpegData(compressionQuality: Self.jpegQuality) else {
            throw CloudKitSharingError.imageCompressionFailed
        }

        return compressedData

        #elseif canImport(AppKit)
        guard let image = NSImage(data: originalData) else {
            throw CloudKitSharingError.imageCompressionFailed
        }

        // Resize if needed
        let resizedImage = resizeImage(image, maxDimension: Self.maxImageDimension)

        // Convert to JPEG
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(
                  using: .jpeg,
                  properties: [.compressionFactor: Self.jpegQuality]
              ) else {
            throw CloudKitSharingError.imageCompressionFailed
        }

        return jpegData
        #endif
    }

    /// Generate a poster thumbnail from the first image
    private func generatePosterImage(from image: ArtworkImage?) async -> Data? {
        guard let image = image else { return nil }

        do {
            let originalData = try Data(contentsOf: image.fileURL)

            #if canImport(UIKit)
            guard let uiImage = UIImage(data: originalData) else { return nil }
            let resized = resizeImage(uiImage, maxDimension: Self.posterSize)
            return resized.jpegData(compressionQuality: 0.7)

            #elseif canImport(AppKit)
            guard let nsImage = NSImage(data: originalData) else { return nil }
            let resized = resizeImage(nsImage, maxDimension: Self.posterSize)
            guard let tiffData = resized.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData) else { return nil }
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
            #endif
        } catch {
            return nil
        }
    }

    #if canImport(UIKit)
    /// Resize a UIImage to fit within maxDimension
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)

        guard maxCurrentDimension > maxDimension else { return image }

        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    #if canImport(AppKit)
    /// Resize an NSImage to fit within maxDimension
    private func resizeImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)

        guard maxCurrentDimension > maxDimension else { return image }

        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: CGRect(origin: .zero, size: newSize),
            from: CGRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()

        return newImage
    }
    #endif

    /// Get image dimensions from ArtworkImage
    private func imageDimensions(for image: ArtworkImage) -> CGSize {
        if let dimensions = image.dimensions {
            return dimensions
        }

        // Try to read from file
        #if canImport(UIKit)
        if let data = try? Data(contentsOf: image.fileURL),
           let uiImage = UIImage(data: data) {
            return uiImage.size
        }
        #elseif canImport(AppKit)
        if let data = try? Data(contentsOf: image.fileURL),
           let nsImage = NSImage(data: data) {
            return nsImage.size
        }
        #endif

        return CGSize(width: 1920, height: 1080) // Default fallback
    }
}
