import Foundation

/// Unified error types for the Arton application
public enum ArtonError: LocalizedError, Sendable {
    // MARK: - iCloud Errors
    case iCloudUnavailable
    case iCloudContainerNotFound
    case iCloudSyncInProgress
    case iCloudPermissionDenied

    // MARK: - Gallery Errors
    case galleryNotFound(name: String)
    case galleryAlreadyExists(name: String)
    case galleryCreationFailed(reason: String)
    case galleryDeletionFailed(reason: String)
    case invalidGalleryName(reason: String)

    // MARK: - Image Errors
    case imageNotFound(filename: String)
    case unsupportedImageFormat(extension: String)
    case imageLoadFailed(filename: String, reason: String)
    case imageCopyFailed(reason: String)
    case imageNotDownloaded(filename: String)

    // MARK: - Settings Errors
    case settingsLoadFailed(reason: String)
    case settingsSaveFailed(reason: String)

    // MARK: - File System Errors
    case fileNotFound(path: String)
    case fileAccessDenied(path: String)
    case fileOperationFailed(operation: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .iCloudContainerNotFound:
            return "Could not access the iCloud container. Please check your iCloud settings."
        case .iCloudSyncInProgress:
            return "iCloud is still syncing. Please wait a moment and try again."
        case .iCloudPermissionDenied:
            return "Permission to access iCloud was denied."

        case .galleryNotFound(let name):
            return "Gallery '\(name)' was not found."
        case .galleryAlreadyExists(let name):
            return "A gallery named '\(name)' already exists."
        case .galleryCreationFailed(let reason):
            return "Failed to create gallery: \(reason)"
        case .galleryDeletionFailed(let reason):
            return "Failed to delete gallery: \(reason)"
        case .invalidGalleryName(let reason):
            return "Invalid gallery name: \(reason)"

        case .imageNotFound(let filename):
            return "Image '\(filename)' was not found."
        case .unsupportedImageFormat(let ext):
            return "Image format '.\(ext)' is not supported. Use JPEG, PNG, HEIC, or GIF."
        case .imageLoadFailed(let filename, let reason):
            return "Failed to load '\(filename)': \(reason)"
        case .imageCopyFailed(let reason):
            return "Failed to copy image: \(reason)"
        case .imageNotDownloaded(let filename):
            return "Image '\(filename)' is not downloaded. Please wait for iCloud to sync."

        case .settingsLoadFailed(let reason):
            return "Failed to load settings: \(reason)"
        case .settingsSaveFailed(let reason):
            return "Failed to save settings: \(reason)"

        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied to: \(path)"
        case .fileOperationFailed(let operation, let reason):
            return "File operation '\(operation)' failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .iCloudUnavailable:
            return "Open Settings > Apple ID > iCloud and sign in."
        case .iCloudSyncInProgress:
            return "Wait for the sync indicator to disappear and try again."
        case .imageNotDownloaded:
            return "Open the Files app and tap the image to download it."
        case .unsupportedImageFormat:
            return "Convert the image to JPEG, PNG, HEIC, or GIF format."
        default:
            return nil
        }
    }
}
