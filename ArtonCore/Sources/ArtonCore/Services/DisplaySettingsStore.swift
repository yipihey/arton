import Foundation

/// Service for persisting global display settings (primarily for tvOS)
///
/// Unlike per-gallery settings which are stored in each gallery folder,
/// display settings are global preferences stored in UserDefaults.
public actor DisplaySettingsStore {
    /// Shared instance for app-wide settings access
    public static let shared = DisplaySettingsStore()

    private let defaults: UserDefaults
    private let settingsKey = "com.arton.displaySettings"

    /// In-memory cache of current settings
    private var cachedSettings: DisplaySettings?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Load display settings from persistent storage
    ///
    /// - Returns: The saved settings, or default settings if none exist
    public func loadSettings() async -> DisplaySettings {
        if let cached = cachedSettings {
            return cached
        }

        guard let data = defaults.data(forKey: settingsKey) else {
            let defaultSettings = DisplaySettings()
            cachedSettings = defaultSettings
            return defaultSettings
        }

        do {
            let decoder = JSONDecoder()
            let settings = try decoder.decode(DisplaySettings.self, from: data)
            cachedSettings = settings
            return settings
        } catch {
            // If decoding fails, return defaults
            let defaultSettings = DisplaySettings()
            cachedSettings = defaultSettings
            return defaultSettings
        }
    }

    /// Save display settings to persistent storage
    ///
    /// - Parameter settings: The settings to save
    public func saveSettings(_ settings: DisplaySettings) async {
        cachedSettings = settings

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            defaults.set(data, forKey: settingsKey)
        } catch {
            // Silently fail - settings will still be in memory cache
        }
    }

    /// Update canvas color and save
    public func setCanvasColor(_ color: CanvasColor) async {
        var settings = await loadSettings()
        settings = DisplaySettings(
            canvasColor: color,
            canvasPadding: settings.canvasPadding,
            selectedGalleryID: settings.selectedGalleryID
        )
        await saveSettings(settings)
    }

    /// Update canvas padding and save
    public func setCanvasPadding(_ padding: Double) async {
        var settings = await loadSettings()
        settings = DisplaySettings(
            canvasColor: settings.canvasColor,
            canvasPadding: padding,
            selectedGalleryID: settings.selectedGalleryID
        )
        await saveSettings(settings)
    }

    /// Update selected gallery and save
    public func setSelectedGallery(_ galleryID: UUID?) async {
        var settings = await loadSettings()
        settings = DisplaySettings(
            canvasColor: settings.canvasColor,
            canvasPadding: settings.canvasPadding,
            selectedGalleryID: galleryID
        )
        await saveSettings(settings)
    }

    /// Clear all saved settings (reset to defaults)
    public func resetToDefaults() async {
        defaults.removeObject(forKey: settingsKey)
        cachedSettings = DisplaySettings()
    }
}

// MARK: - Observable Wrapper for SwiftUI

import Combine

/// Observable wrapper for DisplaySettingsStore for use in SwiftUI views
@MainActor
public class DisplaySettingsManager: ObservableObject {
    public static let shared = DisplaySettingsManager()

    @Published public private(set) var settings: DisplaySettings = DisplaySettings()
    @Published public private(set) var isLoading: Bool = false

    private let store: DisplaySettingsStore

    public init(store: DisplaySettingsStore = .shared) {
        self.store = store
    }

    /// Load settings from storage
    public func loadSettings() async {
        isLoading = true
        settings = await store.loadSettings()
        isLoading = false
    }

    /// Update and persist settings
    public func updateSettings(_ newSettings: DisplaySettings) async {
        settings = newSettings
        await store.saveSettings(newSettings)
    }

    /// Update canvas color
    public func setCanvasColor(_ color: CanvasColor) async {
        await store.setCanvasColor(color)
        settings = await store.loadSettings()
    }

    /// Update canvas padding
    public func setCanvasPadding(_ padding: Double) async {
        await store.setCanvasPadding(padding)
        settings = await store.loadSettings()
    }

    /// Update selected gallery
    public func setSelectedGallery(_ galleryID: UUID?) async {
        await store.setSelectedGallery(galleryID)
        settings = await store.loadSettings()
    }
}
