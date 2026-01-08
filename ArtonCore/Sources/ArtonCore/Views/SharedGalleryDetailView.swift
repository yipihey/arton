import SwiftUI

/// View for browsing images in a shared gallery (read-only)
public struct SharedGalleryDetailView: View {
    public let gallery: SharedGallery

    @StateObject private var viewModel: SharedGalleryViewModel
    @StateObject private var moderationService = ContentModerationService.shared
    @State private var selectedImage: SharedImage?
    @State private var showingReportSheet = false
    @State private var showingBlockConfirmation = false
    @State private var blockError: String?

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var columns: [GridItem] {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)]
        } else {
            [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)]
        }
        #elseif os(macOS)
        [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)]
        #elseif os(tvOS)
        [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 30)]
        #endif
    }

    public init(gallery: SharedGallery) {
        self.gallery = gallery
        self._viewModel = StateObject(wrappedValue: SharedGalleryViewModel(gallery: gallery))
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.images.isEmpty {
                loadingView
            } else if viewModel.images.isEmpty {
                emptyView
            } else {
                imageGrid
            }
        }
        .navigationTitle(gallery.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            toolbarContent
        }
        .task {
            if viewModel.images.isEmpty {
                await viewModel.loadImages()
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            ReportContentSheet(
                galleryID: gallery.id,
                galleryName: gallery.name,
                ownerName: gallery.ownerName
            )
        }
        .confirmationDialog(
            "Block User",
            isPresented: $showingBlockConfirmation
        ) {
            Button("Block \(gallery.ownerName)", role: .destructive) {
                blockUser()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Galleries from \(gallery.ownerName) will no longer appear in your Explore feed. You can unblock them later in Settings.")
        }
        .alert("Error", isPresented: .init(
            get: { blockError != nil },
            set: { if !$0 { blockError = nil } }
        )) {
            Button("OK") { blockError = nil }
        } message: {
            if let error = blockError {
                Text(error)
            }
        }
    }

    // MARK: - Actions

    private func blockUser() {
        Task {
            do {
                try await moderationService.blockUser(
                    ownerRecordID: gallery.ownerRecordID,
                    ownerName: gallery.ownerName
                )
            } catch {
                blockError = error.localizedDescription
            }
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

            Text("Loading images...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Images")
                .font(.title2)
                .fontWeight(.medium)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Image Grid

    private var imageGrid: some View {
        ScrollView {
            galleryInfoHeader

            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(viewModel.images) { image in
                    SharedImageThumbnail(image: image, viewModel: viewModel)
                        #if os(tvOS)
                        .focusable()
                        #endif
                        .onTapGesture {
                            selectedImage = image
                        }
                }

                // Load more trigger
                if viewModel.hasMore {
                    loadMoreView
                }
            }
            .padding(gridPadding)
        }
    }

    private var galleryInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(gallery.imageCount) images")
                Text("•")
                Text("Shared by \(gallery.ownerName)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let description = gallery.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, gridPadding)
        .padding(.top, 8)
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
                        viewModel.loadMoreImages()
                    }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS) || os(macOS)
        ToolbarItem(placement: .primaryAction) {
            ShareLink(item: gallery.shareURL) {
                Label("Share Link", systemImage: "link")
            }
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button {
                    showingReportSheet = true
                } label: {
                    Label("Report Gallery", systemImage: "flag")
                }

                Button(role: .destructive) {
                    showingBlockConfirmation = true
                } label: {
                    Label("Block User", systemImage: "person.slash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        #elseif os(tvOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingReportSheet = true
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
        #endif
    }

    private var gridSpacing: CGFloat {
        #if os(tvOS)
        30
        #elseif os(iOS)
        horizontalSizeClass == .regular ? 12 : 8
        #else
        16
        #endif
    }

    private var gridPadding: CGFloat {
        #if os(tvOS)
        60
        #elseif os(macOS)
        20
        #elseif os(iOS)
        horizontalSizeClass == .regular ? 20 : 16
        #else
        16
        #endif
    }
}

// MARK: - Shared Image Thumbnail

/// Thumbnail view for a shared image with async loading
struct SharedImageThumbnail: View {
    let image: SharedImage
    @ObservedObject var viewModel: SharedGalleryViewModel

    @State private var imageData: Data?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let data = imageData ?? viewModel.imageDataCache[image.id],
               let platformImg = platformImage(from: data) {
                Image(platformImage: platformImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else {
                placeholderView
            }
        }
        .cornerRadius(8)
        .task {
            if imageData == nil && viewModel.imageDataCache[image.id] == nil {
                isLoading = true
                imageData = await viewModel.loadImageData(for: image)
                isLoading = false
            }
        }
    }

    private var placeholderView: some View {
        ZStack {
            #if os(iOS)
            Color(uiColor: .tertiarySystemBackground)
            #elseif os(macOS)
            Color(nsColor: .controlBackgroundColor)
            #else
            Color.secondary.opacity(0.3)
            #endif

            if isLoading || viewModel.loadingImageIDs.contains(image.id) {
                ProgressView()
            } else {
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundStyle(.tertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
        SharedGalleryDetailView(gallery: SharedGallery(
            id: "preview",
            galleryID: UUID(),
            name: "Sample Gallery",
            description: "A beautiful collection of artwork",
            ownerName: "John Doe",
            ownerRecordID: "user123",
            imageCount: 42,
            posterImageData: nil,
            isPublic: true
        ))
    }
}
#endif
