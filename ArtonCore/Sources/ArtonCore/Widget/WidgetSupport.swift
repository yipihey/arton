import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Widget Artwork Data

/// Data structure for widget artwork display
public struct WidgetArtworkData: Sendable {
    public let galleryName: String
    public let imagePath: String?
    public let imageCount: Int

    public init(galleryName: String, imagePath: String?, imageCount: Int) {
        self.galleryName = galleryName
        self.imagePath = imagePath
        self.imageCount = imageCount
    }
}

// MARK: - Widget Helper

/// Shared helper for loading widget artwork data
public enum WidgetHelper {
    /// Supported image extensions for galleries
    private static let supportedExtensions = ["jpg", "jpeg", "png", "heic", "gif"]

    /// Load random artwork data from iCloud galleries
    public static func loadRandomArtwork() async -> WidgetArtworkData {
        let fileManager = FileManager.default

        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.arton.galleries") else {
            return WidgetArtworkData(galleryName: "No iCloud", imagePath: nil, imageCount: 0)
        }

        let galleriesURL = containerURL.appendingPathComponent("Documents/Arton/Galleries")

        guard let galleries = try? fileManager.contentsOfDirectory(
            at: galleriesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return WidgetArtworkData(galleryName: "No Galleries", imagePath: nil, imageCount: 0)
        }

        let galleryFolders = galleries.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        guard !galleryFolders.isEmpty else {
            return WidgetArtworkData(galleryName: "No Galleries", imagePath: nil, imageCount: 0)
        }

        // Pick a random gallery
        let randomGallery = galleryFolders.randomElement()!
        let galleryName = randomGallery.lastPathComponent

        // Get images in the gallery
        guard let contents = try? fileManager.contentsOfDirectory(
            at: randomGallery,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return WidgetArtworkData(galleryName: galleryName, imagePath: nil, imageCount: 0)
        }

        let images = contents.filter { url in
            supportedExtensions.contains(url.pathExtension.lowercased())
        }

        guard !images.isEmpty else {
            return WidgetArtworkData(galleryName: galleryName, imagePath: nil, imageCount: 0)
        }

        // Pick a random image
        let randomImage = images.randomElement()!

        return WidgetArtworkData(
            galleryName: galleryName,
            imagePath: randomImage.path,
            imageCount: images.count
        )
    }

    /// Load a thumbnail image for widget display
    public static func loadWidgetImage(from path: String, size: CGSize, scaleFactor: CGFloat) -> PlatformImage? {
        let url = URL(fileURLWithPath: path)
        let maxDimension = max(size.width, size.height) * scaleFactor

        return ImageUtilities.generateThumbnail(from: url, maxSize: maxDimension)
    }
}

// MARK: - SwiftUI Image Extension for PlatformImage

public extension Image {
    /// Create an Image from a PlatformImage
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - Widget Artwork View

/// Shared view for displaying artwork in widgets
public struct WidgetArtworkView: View {
    let galleryName: String
    let imagePath: String?
    let imageCount: Int
    let showImageCount: Bool
    let size: CGSize

    public init(
        galleryName: String,
        imagePath: String?,
        imageCount: Int,
        showImageCount: Bool,
        size: CGSize
    ) {
        self.galleryName = galleryName
        self.imagePath = imagePath
        self.imageCount = imageCount
        self.showImageCount = showImageCount
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background
            if let imagePath = imagePath,
               let image = loadImage(from: imagePath) {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // Placeholder gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Overlay with gallery info
            VStack {
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(galleryName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)

                        if showImageCount && imageCount > 0 {
                            Text("\(imageCount) images")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(radius: 2)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private func loadImage(from path: String) -> PlatformImage? {
        #if canImport(UIKit)
        let scaleFactor = UIScreen.main.scale
        #elseif canImport(AppKit)
        let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
        #endif

        return WidgetHelper.loadWidgetImage(from: path, size: size, scaleFactor: scaleFactor)
    }
}
