import SwiftUI

/// A grid view displaying multiple galleries
///
/// This view presents galleries in a responsive grid layout, adapting to
/// the available screen size. Each gallery is displayed using GalleryRowView.
public struct GalleryGridView: View {
    /// The galleries to display
    let galleries: [Gallery]

    /// Action when a gallery is selected
    var onSelect: ((Gallery) -> Void)?

    /// Action when a gallery should be deleted
    var onDelete: ((Gallery) -> Void)?

    /// Size for gallery thumbnails
    var thumbnailSize: CGFloat

    /// Number of columns (adaptive if nil)
    var columns: Int?

    public init(
        galleries: [Gallery],
        thumbnailSize: CGFloat = 120,
        columns: Int? = nil,
        onSelect: ((Gallery) -> Void)? = nil,
        onDelete: ((Gallery) -> Void)? = nil
    ) {
        self.galleries = galleries
        self.thumbnailSize = thumbnailSize
        self.columns = columns
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        if galleries.isEmpty {
            emptyState
        } else {
            gridContent
        }
    }

    // MARK: - Grid Content

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(galleries) { gallery in
                    galleryCard(for: gallery)
                }
            }
            .padding()
        }
    }

    private var gridColumns: [GridItem] {
        if let columns = columns {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: columns)
        } else {
            // Adaptive columns based on thumbnail size
            return [GridItem(.adaptive(minimum: thumbnailSize + 100, maximum: 400), spacing: 20)]
        }
    }

    private func galleryCard(for gallery: Gallery) -> some View {
        Button {
            onSelect?(gallery)
        } label: {
            GalleryRowView(gallery: gallery, thumbnailSize: thumbnailSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .contextMenu {
            deleteButton(for: gallery)
        }
        #elseif os(macOS)
        .contextMenu {
            deleteButton(for: gallery)
        }
        #endif
    }

    @ViewBuilder
    private func deleteButton(for gallery: Gallery) -> some View {
        if onDelete != nil {
            Button(role: .destructive) {
                onDelete?(gallery)
            } label: {
                Label("Delete Gallery", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Galleries")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a gallery to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Variant

/// A list view displaying galleries (alternative to grid)
public struct GalleryListView: View {
    let galleries: [Gallery]
    var onSelect: ((Gallery) -> Void)?
    var onDelete: ((Gallery) -> Void)?

    public init(
        galleries: [Gallery],
        onSelect: ((Gallery) -> Void)? = nil,
        onDelete: ((Gallery) -> Void)? = nil
    ) {
        self.galleries = galleries
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        if galleries.isEmpty {
            emptyState
        } else {
            List {
                ForEach(galleries) { gallery in
                    Button {
                        onSelect?(gallery)
                    } label: {
                        GalleryRowView(gallery: gallery, thumbnailSize: 80)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteGalleries)
            }
            .listStyle(.plain)
        }
    }

    private func deleteGalleries(at offsets: IndexSet) {
        for index in offsets {
            onDelete?(galleries[index])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Galleries")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a gallery to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Grid - Empty") {
    GalleryGridView(galleries: [])
}

#Preview("List - Empty") {
    GalleryListView(galleries: [])
}
#endif
