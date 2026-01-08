import Foundation

/// Actor responsible for loading and saving per-gallery settings
///
/// Settings are stored as `.arton-settings.json` files within each gallery folder.
/// This actor ensures thread-safe access to settings files across the application.
public actor GallerySettingsStore {
    /// Shared instance for app-wide settings access
    public static let shared = GallerySettingsStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        decoder = JSONDecoder()
    }

    /// Load settings for a gallery
    ///
    /// - Parameter galleryURL: The URL of the gallery folder
    /// - Returns: The gallery's settings, or default settings if no settings file exists
    /// - Throws: `ArtonError.settingsLoadFailed` if the settings file exists but cannot be parsed
    public func loadSettings(for galleryURL: URL) async throws -> GallerySettings {
        let settingsURL = galleryURL.appendingPathComponent(GallerySettings.filename)

        // If settings file doesn't exist, return defaults
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return GallerySettings.default
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try decoder.decode(GallerySettings.self, from: data)
            return settings
        } catch {
            throw ArtonError.settingsLoadFailed(reason: error.localizedDescription)
        }
    }

    /// Save settings to a gallery folder
    ///
    /// - Parameters:
    ///   - settings: The settings to save
    ///   - galleryURL: The URL of the gallery folder
    /// - Throws: `ArtonError.settingsSaveFailed` if the settings cannot be written
    public func saveSettings(_ settings: GallerySettings, to galleryURL: URL) async throws {
        let settingsURL = galleryURL.appendingPathComponent(GallerySettings.filename)

        do {
            // Ensure the gallery directory exists
            if !fileManager.fileExists(atPath: galleryURL.path) {
                try fileManager.createDirectory(at: galleryURL, withIntermediateDirectories: true)
            }

            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            throw ArtonError.settingsSaveFailed(reason: error.localizedDescription)
        }
    }
}
