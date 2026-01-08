import SwiftUI
import ArtonCore

/// Gallery selection grid for tvOS
/// Displays available galleries with large thumbnails suitable for TV viewing
struct GalleryPickerView: View {
    let galleries: [Gallery]
    var isLoading: Bool = false
    var onSelect: ((Gallery) -> Void)?

    /// Large thumbnail size for TV viewing (200pt+)
    private let thumbnailSize: CGFloat = 300

    /// Grid columns for tvOS - 3 columns works well on TV
    private let columns = [
        GridItem(.flexible(), spacing: 48),
        GridItem(.flexible(), spacing: 48),
        GridItem(.flexible(), spacing: 48)
    ]

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if galleries.isEmpty {
                emptyStateView
            } else {
                galleryGrid
            }
        }
    }

    // MARK: - Gallery Grid

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 60) {
                ForEach(galleries) { gallery in
                    GalleryCardView(
                        gallery: gallery,
                        thumbnailSize: thumbnailSize,
                        onSelect: {
                            onSelect?(gallery)
                        }
                    )
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)

            Text("Loading Galleries...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 120))
                .foregroundStyle(.tertiary)

            Text("No Galleries")
                .font(.largeTitle)
                .fontWeight(.medium)

            Text("Add galleries using the Arton app on your iPhone, iPad, or Mac")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Gallery Card View

/// Individual gallery card optimized for tvOS focus engine
private struct GalleryCardView: View {
    let gallery: Gallery
    let thumbnailSize: CGFloat
    var onSelect: (() -> Void)?

    @State private var thumbnailImage: PlatformImage?
    @State private var isLoading: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail
                thumbnailView
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: isFocused ? 20 : 8)

                // Gallery info
                VStack(alignment: .leading, spacing: 4) {
                    Text(gallery.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)

                    Text(imageCountText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(width: thumbnailSize, alignment: .leading)
            }
        }
        .buttonStyle(TVCardButtonStyle())
        .focused($isFocused)
        .task(id: gallery.id) {
            await loadThumbnail()
        }
    }

    // MARK: - Thumbnail View

    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            #if canImport(UIKit)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipped()
            #endif
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color(white: 0.15)

            if isLoading && (gallery.cachedImageCount ?? 0) > 0 {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: thumbnailSize * 0.25))
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

        guard let posterArtwork = await GalleryManager.shared.posterImage(for: gallery) else {
            thumbnailImage = nil
            return
        }

        thumbnailImage = await ThumbnailCache.shared.thumbnail(
            for: posterArtwork.fileURL,
            size: thumbnailSize * 2
        )
    }
}

// MARK: - TV Card Button Style

/// Custom button style for tvOS focus engine support
private struct TVCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Gallery Picker - With Galleries") {
    NavigationStack {
        GalleryPickerView(
            galleries: [],
            isLoading: false
        )
        .navigationTitle("Arton")
    }
}

#Preview("Gallery Picker - Empty") {
    NavigationStack {
        GalleryPickerView(
            galleries: [],
            isLoading: false
        )
        .navigationTitle("Arton")
    }
}

#Preview("Gallery Picker - Loading") {
    NavigationStack {
        GalleryPickerView(
            galleries: [],
            isLoading: true
        )
        .navigationTitle("Arton")
    }
}
