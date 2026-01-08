import SwiftUI

/// View displaying public shared galleries for discovery
public struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedGallery: SharedGallery?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var columns: [GridItem] {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            [GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 16)]
        } else {
            [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]
        }
        #elseif os(macOS)
        [GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 16)]
        #elseif os(tvOS)
        [GridItem(.adaptive(minimum: 400, maximum: 500), spacing: 40)]
        #endif
    }

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.galleries.isEmpty {
                loadingView
            } else if viewModel.galleries.isEmpty {
                emptyView
            } else {
                galleryGrid
            }
        }
        .navigationTitle("Explore")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
        #endif
        .task {
            if viewModel.galleries.isEmpty {
                await viewModel.loadInitial()
            }
        }
        .navigationDestination(item: $selectedGallery) { gallery in
            SharedGalleryDetailView(gallery: gallery)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                #if os(tvOS)
                .scaleEffect(2)
                #else
                .scaleEffect(1.5)
                #endif

            Text("Loading galleries...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Galleries Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Be the first to share a gallery!\nShared galleries will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)

                Button("Try Again") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Gallery Grid

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(viewModel.galleries) { gallery in
                    SharedGalleryCard(gallery: gallery)
                        #if os(tvOS)
                        .focusable()
                        #endif
                        .onTapGesture {
                            selectedGallery = gallery
                        }
                        #if os(tvOS)
                        .onLongPressGesture {
                            selectedGallery = gallery
                        }
                        #endif
                }

                // Load more trigger
                if viewModel.hasMore {
                    loadMoreView
                }
            }
            .padding(gridPadding)
        }
    }

    private var loadMoreView: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            } else {
                Color.clear
                    .frame(height: 50)
                    .onAppear {
                        viewModel.loadMore()
                    }
            }
        }
    }

    private var gridSpacing: CGFloat {
        #if os(tvOS)
        40
        #else
        16
        #endif
    }

    private var gridPadding: CGFloat {
        #if os(tvOS)
        60
        #elseif os(macOS)
        20
        #else
        16
        #endif
    }
}

// MARK: - Shared Gallery Card

/// Card view for displaying a shared gallery in the Explore grid
public struct SharedGalleryCard: View {
    public let gallery: SharedGallery

    public init(gallery: SharedGallery) {
        self.gallery = gallery
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster image
            posterImage
                .aspectRatio(4/3, contentMode: .fill)
                .clipped()

            // Gallery info
            VStack(alignment: .leading, spacing: 4) {
                Text(gallery.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text("\(gallery.imageCount) images")
                    Text("•")
                    Text("by \(gallery.ownerName)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let description = gallery.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #elseif os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #elseif os(tvOS)
        .background(Color.secondary.opacity(0.2))
        #endif
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterData = gallery.posterImageData,
           let image = platformImage(from: posterData) {
            Image(platformImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                #if os(iOS)
                Color(uiColor: .tertiarySystemBackground)
                #elseif os(macOS)
                Color(nsColor: .controlBackgroundColor)
                #else
                Color.secondary.opacity(0.3)
                #endif

                Image(systemName: "photo.stack")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func platformImage(from data: Data) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ExploreView()
    }
}
#endif
