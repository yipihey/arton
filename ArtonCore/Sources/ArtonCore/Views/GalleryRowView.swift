import SwiftUI

/// A reusable view displaying a single gallery with its poster image
///
/// Shows a thumbnail of the gallery's poster image (first image alphabetically),
/// the gallery name, and the image count. Uses async loading for the thumbnail.
public struct GalleryRowView: View {
    let gallery: Gallery
    var thumbnailSize: CGFloat = 120

    @State private var thumbnailImage: PlatformImage?
    @State private var isLoading: Bool = true

    public init(gallery: Gallery, thumbnailSize: CGFloat = 120) {
        self.gallery = gallery
        self.thumbnailSize = thumbnailSize
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            thumbnailView
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(gallery.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(imageCountText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .task(id: gallery.id) {
            await loadThumbnail()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
            #elseif canImport(AppKit)
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
            #endif
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color(white: 0.9)

            if isLoading && (gallery.cachedImageCount ?? 0) > 0 {
                ProgressView()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: thumbnailSize * 0.3))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var imageCountText: String {
        guard let count = gallery.cachedImageCount else {
            return "Loading..."
        }

        switch count {
        case 0:
            return "Empty"
        case 1:
            return "1 image"
        default:
            return "\(count) images"
        }
    }

    // MARK: - Loading

    private func loadThumbnail() async {
        isLoading = true
        defer { isLoading = false }

        // Get the poster image for the gallery
        guard let posterArtwork = await GalleryManager.shared.posterImage(for: gallery) else {
            thumbnailImage = nil
            return
        }

        // Load the thumbnail from cache
        thumbnailImage = await ThumbnailCache.shared.thumbnail(
            for: posterArtwork.fileURL,
            size: thumbnailSize * 2 // Request 2x for Retina displays
        )
    }
}
