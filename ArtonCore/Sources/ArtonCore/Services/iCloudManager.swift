import Foundation

/// Manages iCloud Drive folder operations for gallery storage.
///
/// This actor provides thread-safe access to the iCloud container,
/// handling gallery folder creation, deletion, listing, and renaming.
///
/// Galleries are stored as folders at: `iCloud Drive/Arton/Galleries/<gallery-name>/`
public actor iCloudManager {

    // MARK: - Singleton

    /// Shared instance for app-wide use
    public static let shared = iCloudManager()

    // MARK: - Constants

    /// The iCloud container identifier for Arton
    private static let containerIdentifier = "iCloud.com.arton.galleries"

    /// Root folder name within the iCloud container
    private static let rootFolderName = "Arton"

    /// Subfolder name for galleries
    private static let galleriesFolderName = "Galleries"

    /// Characters that are not allowed in gallery names
    private static let invalidNameCharacters = CharacterSet(charactersIn: "/:\\")

    // MARK: - Cached State

    /// Cached base URL for galleries (computed once and reused)
    private var cachedGalleriesBaseURL: URL?

    // MARK: - Initialization

    /// Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Public API

    /// Get the base URL for galleries in iCloud Drive.
    ///
    /// This method returns the URL to `iCloud Drive/Arton/Galleries/`,
    /// creating the directory structure if it doesn't exist.
    ///
    /// - Returns: The URL to the galleries base directory
    /// - Throws: `ArtonError.iCloudUnavailable` if iCloud is not available,
    ///           `ArtonError.iCloudContainerNotFound` if the container cannot be accessed
    public func galleriesBaseURL() async throws -> URL {
        // Return cached URL if available
        if let cachedURL = cachedGalleriesBaseURL {
            // Verify it still exists
            if FileManager.default.fileExists(atPath: cachedURL.path) {
                return cachedURL
            }
            // Clear cache if directory no longer exists
            cachedGalleriesBaseURL = nil
        }

        // Get the iCloud container URL
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: Self.containerIdentifier
        ) else {
            throw ArtonError.iCloudUnavailable
        }

        // Build the path: container/Arton/Galleries/
        let galleriesURL = containerURL
            .appendingPathComponent(Self.rootFolderName, isDirectory: true)
            .appendingPathComponent(Self.galleriesFolderName, isDirectory: true)

        // Create the directory structure if needed
        if !FileManager.default.fileExists(atPath: galleriesURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: galleriesURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                throw ArtonError.galleryCreationFailed(
                    reason: "Could not create galleries directory: \(error.localizedDescription)"
                )
            }
        }

        // Cache and return
        cachedGalleriesBaseURL = galleriesURL
        return galleriesURL
    }

    /// List all gallery folder URLs in iCloud Drive.
    ///
    /// Returns URLs for all directories in the galleries base folder.
    /// Files (non-directories) are excluded from the results.
    ///
    /// - Returns: An array of URLs pointing to gallery folders, sorted alphabetically by name
    /// - Throws: `ArtonError.iCloudUnavailable` if iCloud is not available
    public func listGalleryFolders() async throws -> [URL] {
        let baseURL = try await galleriesBaseURL()

        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            )

            // Filter to only include directories
            let galleryFolders = contents.filter { url in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }

            // Sort alphabetically by folder name
            return galleryFolders.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        } catch {
            throw ArtonError.fileOperationFailed(
                operation: "list galleries",
                reason: error.localizedDescription
            )
        }
    }

    /// Create a new gallery folder in iCloud Drive.
    ///
    /// - Parameter name: The name for the new gallery folder
    /// - Returns: The URL of the newly created gallery folder
    /// - Throws: `ArtonError.invalidGalleryName` if the name is empty or contains invalid characters,
    ///           `ArtonError.galleryAlreadyExists` if a gallery with that name already exists,
    ///           `ArtonError.galleryCreationFailed` if the folder could not be created
    public func createGalleryFolder(named name: String) async throws -> URL {
        // Validate the gallery name
        try validateGalleryName(name)

        let baseURL = try await galleriesBaseURL()
        let galleryURL = baseURL.appendingPathComponent(name, isDirectory: true)

        // Check if gallery already exists
        if FileManager.default.fileExists(atPath: galleryURL.path) {
            throw ArtonError.galleryAlreadyExists(name: name)
        }

        // Create the gallery folder
        do {
            try FileManager.default.createDirectory(
                at: galleryURL,
                withIntermediateDirectories: false,
                attributes: nil
            )
            return galleryURL
        } catch {
            throw ArtonError.galleryCreationFailed(
                reason: error.localizedDescription
            )
        }
    }

    /// Delete a gallery folder from iCloud Drive.
    ///
    /// This permanently removes the gallery folder and all its contents.
    ///
    /// - Parameter url: The URL of the gallery folder to delete
    /// - Throws: `ArtonError.galleryNotFound` if the gallery doesn't exist,
    ///           `ArtonError.galleryDeletionFailed` if the deletion fails
    public func deleteGalleryFolder(at url: URL) async throws {
        let fileManager = FileManager.default

        // Verify the folder exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ArtonError.galleryNotFound(name: url.lastPathComponent)
        }

        // Delete the folder
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw ArtonError.galleryDeletionFailed(
                reason: error.localizedDescription
            )
        }
    }

    /// Rename a gallery folder in iCloud Drive.
    ///
    /// - Parameters:
    ///   - url: The URL of the gallery folder to rename
    ///   - newName: The new name for the gallery
    /// - Returns: The URL of the renamed gallery folder
    /// - Throws: `ArtonError.galleryNotFound` if the gallery doesn't exist,
    ///           `ArtonError.invalidGalleryName` if the new name is invalid,
    ///           `ArtonError.galleryAlreadyExists` if a gallery with the new name already exists,
    ///           `ArtonError.fileOperationFailed` if the rename fails
    public func renameGalleryFolder(at url: URL, to newName: String) async throws -> URL {
        // Validate the new name
        try validateGalleryName(newName)

        let fileManager = FileManager.default

        // Verify the source folder exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ArtonError.galleryNotFound(name: url.lastPathComponent)
        }

        // Build the new URL
        let baseURL = try await galleriesBaseURL()
        let newURL = baseURL.appendingPathComponent(newName, isDirectory: true)

        // Check if destination already exists (unless it's the same folder with different case)
        if fileManager.fileExists(atPath: newURL.path) {
            // Allow case-only renames on case-insensitive file systems
            if url.lastPathComponent.lowercased() != newName.lowercased() {
                throw ArtonError.galleryAlreadyExists(name: newName)
            }
        }

        // Perform the rename
        do {
            try fileManager.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            throw ArtonError.fileOperationFailed(
                operation: "rename gallery",
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Private Helpers

    /// Validates a gallery name for invalid characters and empty strings.
    ///
    /// - Parameter name: The gallery name to validate
    /// - Throws: `ArtonError.invalidGalleryName` if the name is invalid
    private func validateGalleryName(_ name: String) throws {
        // Check for empty or whitespace-only names
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ArtonError.invalidGalleryName(reason: "Gallery name cannot be empty")
        }

        // Check for invalid characters
        if name.unicodeScalars.contains(where: { Self.invalidNameCharacters.contains($0) }) {
            throw ArtonError.invalidGalleryName(
                reason: "Gallery name cannot contain /, \\, or : characters"
            )
        }

        // Check for names that start with a dot (hidden files)
        if name.hasPrefix(".") {
            throw ArtonError.invalidGalleryName(
                reason: "Gallery name cannot start with a period"
            )
        }

        // Check for excessively long names (file system limit is typically 255)
        if name.count > 255 {
            throw ArtonError.invalidGalleryName(
                reason: "Gallery name is too long (maximum 255 characters)"
            )
        }
    }
}
