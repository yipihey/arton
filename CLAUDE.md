# Arton - Claude Code Briefing

## Project Overview

A cross-platform art display system for Apple TV with companion iOS and macOS apps for gallery curation.

- **Arton-tvOS**: Displays artwork slideshows on Apple TV
- **Arton-iOS**: Curate galleries from iPhone/iPad
- **Arton-macOS**: Curate galleries from Mac with drag-and-drop

Target users: Art enthusiasts who want to display their image collections on TV.

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│ tvOS App       │ iOS App        │ macOS App                 │
│ └─ Slideshow   │ └─ Curation UI │ └─ Curation UI            │
├─────────────────────────────────────────────────────────────┤
│                       ArtonCore                             │
│            (Swift Package - shared across all apps)         │
│          Models │ Services │ Views │ Errors                 │
├─────────────────────────────────────────────────────────────┤
│                      iCloud Drive                           │
│              (Galleries stored as folders)                  │
└─────────────────────────────────────────────────────────────┘
```

### Package Structure
- **ArtonCore**: Swift Package containing shared code (95%)
- **Arton-tvOS**: Thin shell for tvOS-specific UI
- **Arton-iOS**: Thin shell for iOS-specific UI
- **Arton-macOS**: Thin shell for macOS-specific UI

## Key Design Decisions

### Storage
- Galleries are **folders in iCloud Drive** at `iCloud Drive/Arton/Galleries/`
- Each folder = one gallery (flat structure, no subfolders)
- Images stored directly in gallery folders
- **Gallery settings** stored in `.arton-settings.json` inside each gallery folder
- **Global display settings** (tvOS canvas, selected gallery) stored in UserDefaults
- No database - file system is the source of truth

### Supported Image Formats
- JPEG (.jpg, .jpeg)
- PNG (.png)
- HEIC (.heic)
- GIF (.gif)

### Gallery Features
- **Display Order**: Serial (alphabetical), Random (shuffle), Back & Forth (ping-pong)
- **Transition Effects**: Fade, Slide, Dissolve, Push, None
- **Transition Duration**: Per-effect defaults, optionally customizable
- **Display Interval**: 10s to 1 hour presets
- **Poster Frame**: First image alphabetically in each gallery

### tvOS Display
- Full-screen artwork display with proper aspect ratio
- Image fits within canvas (no cropping)
- **Canvas Colors**: Black or Eggshell background
- **Canvas Padding**: Adjustable 0-25% around image
- Siri Remote: Play/pause, next/previous, gallery selection

### Platform Abstractions
```swift
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif
```

## Key Types

### Gallery Model
```swift
struct Gallery: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var folderURL: URL
    var createdAt: Date
    var modifiedAt: Date
    var cachedImageCount: Int?  // Avoid enumeration on every load
}
```

### Gallery Settings (per-gallery, stored in .arton-settings.json)
```swift
struct GallerySettings: Codable, Sendable, Equatable {
    var displayOrder: DisplayOrder        // .serial, .random, .pingPong
    var transitionEffect: TransitionEffect // .fade, .slide, .dissolve, .push, .none
    var transitionDuration: TimeInterval?  // nil = use effect default
    var displayInterval: TimeInterval      // seconds between images
}
```

### Artwork Image
```swift
struct ArtworkImage: Identifiable, Sendable, Hashable {
    let id: String              // Stable hash of relative path within gallery
    let fileURL: URL
    let filename: String
    var sortKey: String         // lowercase filename for sorting
    var isDownloaded: Bool      // false if iCloud-evicted
    var fileSizeBytes: Int64?
    var dimensions: CGSize?
}
```

### Display Settings (tvOS global)
```swift
struct DisplaySettings: Codable, Sendable, Equatable {
    var canvasColor: CanvasColor    // .black, .eggshell
    var canvasPadding: Double       // 0.0 - 0.25
    var selectedGalleryID: UUID?
}
```

### Enums
```swift
enum DisplayOrder: String, Codable, Sendable, CaseIterable {
    case serial, random, pingPong
}

enum TransitionEffect: String, Codable, Sendable, CaseIterable {
    case fade, slide, dissolve, push, none
    var defaultDuration: TimeInterval { /* 0-1s depending on effect */ }
}

enum CanvasColor: String, Codable, Sendable, CaseIterable {
    case black, eggshell
}
```

## Error Handling

All errors are unified under `ArtonError`:
```swift
enum ArtonError: LocalizedError, Sendable {
    // iCloud
    case iCloudUnavailable
    case iCloudContainerNotFound
    case iCloudSyncInProgress

    // Gallery
    case galleryNotFound(name: String)
    case galleryAlreadyExists(name: String)
    case galleryCreationFailed(reason: String)

    // Image
    case imageNotFound(filename: String)
    case unsupportedImageFormat(extension: String)
    case imageLoadFailed(filename: String, reason: String)
    case imageNotDownloaded(filename: String)

    // Settings
    case settingsLoadFailed(reason: String)
    case settingsSaveFailed(reason: String)
}
```

## Services

```swift
// iCloud folder management
actor iCloudManager {
    func galleriesBaseURL() -> URL
    func listGalleryFolders() throws -> [URL]
    func createGalleryFolder(named: String) throws -> URL
    func deleteGalleryFolder(at: URL) throws
}

// Gallery settings (per-gallery .arton-settings.json)
actor GallerySettingsStore {
    func loadSettings(for gallery: Gallery) async throws -> GallerySettings
    func saveSettings(_ settings: GallerySettings, for gallery: Gallery) async throws
}

// Gallery and image loading
@MainActor class GalleryManager: ObservableObject {
    @Published var galleries: [Gallery]
    func loadGalleries() async
    func loadImages(for: Gallery) async throws -> [ArtworkImage]
    func posterImage(for: Gallery) async -> ArtworkImage?
}

// Slideshow control (tvOS)
@MainActor class SlideshowController: ObservableObject {
    @Published var currentImage: ArtworkImage?
    @Published var isPlaying: Bool
    func loadGallery(_ gallery: Gallery) async
    func start() / pause() / next() / previous()
}

// Image utilities
enum ImageUtilities {
    static func loadImage(from url: URL) -> PlatformImage?
    static func imageDimensions(at url: URL) -> CGSize?
    static func generateThumbnail(from url: URL, maxSize: CGFloat) -> PlatformImage?
}
```

## File Organization

```
ArtonCore/
├── Package.swift
├── Sources/ArtonCore/
│   ├── ArtonCore.swift           # Package entry point
│   ├── Models/
│   │   ├── Gallery.swift
│   │   ├── GallerySettings.swift  # Per-gallery settings
│   │   ├── ArtworkImage.swift
│   │   ├── DisplaySettings.swift  # tvOS global settings
│   │   ├── DisplayOrder.swift
│   │   ├── TransitionEffect.swift
│   │   └── CanvasColor.swift
│   ├── Services/
│   │   ├── iCloudManager.swift
│   │   ├── GalleryManager.swift
│   │   ├── GallerySettingsStore.swift
│   │   ├── SlideshowController.swift
│   │   └── ThumbnailCache.swift
│   ├── Views/
│   │   ├── GalleryGridView.swift
│   │   ├── ArtworkDisplayView.swift
│   │   └── GallerySettingsView.swift
│   ├── Errors/
│   │   └── ArtonError.swift
│   └── Platform/
│       └── PlatformImage.swift    # Platform typealias + ImageUtilities
└── Tests/ArtonCoreTests/
    └── ArtonCoreTests.swift

Arton-tvOS/
├── ArtonApp.swift
├── ContentView.swift
├── GalleryPickerView.swift
├── SlideshowView.swift
└── SettingsView.swift

Arton-iOS/
├── ArtonApp.swift
├── ContentView.swift
├── GalleryListView.swift
└── GalleryDetailView.swift

Arton-macOS/
├── ArtonApp.swift
├── ContentView.swift
├── SidebarView.swift
├── GalleryDetailView.swift
└── Arton.entitlements
```

## Coding Conventions

### Swift Style
- Swift 5.9+, iOS/tvOS 17+, macOS 14+
- `actor` for thread-safe services (iCloudManager, GallerySettingsStore)
- `@MainActor class` with `@Published` for view models
- `struct` for data models, conforming to `Sendable`
- Prefer async/await over callbacks

### Platform Differences
- Use `#if os(tvOS)` / `#if os(iOS)` / `#if os(macOS)` sparingly
- Shared views use conditional compilation for platform differences
- Abstract platform APIs behind protocols when needed

## Commands

```bash
# Build the Swift Package
cd ArtonCore && swift build

# Run tests
cd ArtonCore && swift test

# Open in Xcode (after creating workspace)
open Arton.xcworkspace
```

## Phase Checklist

### Phase 1: Foundation (Current)
- [x] ArtonCore Swift Package structure
- [x] Gallery, ArtworkImage, DisplaySettings models
- [x] GallerySettings model (per-gallery .arton-settings.json)
- [x] ArtonError for unified error handling
- [x] ImageUtilities for platform-agnostic image loading
- [ ] iCloudManager for folder operations
- [ ] GalleryManager for loading galleries/images
- [ ] SlideshowController for tvOS playback
- [ ] Basic tvOS gallery picker and slideshow
- [ ] Basic iOS/macOS gallery list and detail views

### Phase 2: Polish
- [ ] Transition animations between images
- [ ] PhotosPicker integration (iOS)
- [ ] Drag-and-drop import (macOS)
- [ ] Gallery settings editing UI
- [ ] Canvas color/padding adjustment (tvOS)
- [ ] ThumbnailCache for gallery browsing performance

### Phase 3: Enhancement
- [ ] Siri Remote gestures (swipe, click)
- [ ] Widget for iOS/macOS
- [ ] Top Shelf extension for tvOS
- [ ] Background music support
- [ ] Screensaver mode

## iCloud Container

Bundle ID: `iCloud.com.arton.galleries`

Required entitlements:
- `com.apple.developer.icloud-container-identifiers`
- `com.apple.developer.icloud-services` (CloudDocuments)
- `com.apple.developer.ubiquity-container-identifiers`

## Gallery Folder Structure

```
iCloud Drive/
└── Arton/
    └── Galleries/
        ├── Nature/
        │   ├── .arton-settings.json    # Display order, transition, interval
        │   ├── mountain.jpg
        │   ├── ocean.png
        │   └── sunset.heic
        └── Abstract Art/
            ├── .arton-settings.json
            ├── waves.jpg
            └── colors.png
```
