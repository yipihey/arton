import SwiftUI
import ArtonCore
import PhotosUI

struct GalleryDetailView: View {
    let gallery: Gallery

    @StateObject private var galleryManager = GalleryManager.shared
    @State private var images: [ArtworkImage] = []
    @State private var isLoading = true
    @State private var settings = GallerySettings()
    @State private var showingSettings = false
    @State private var showingSlideshow = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var imageToDelete: ArtworkImage?
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad: larger thumbnails with more spacing
            [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)]
        } else {
            // iPhone: compact thumbnails
            [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)]
        }
    }

    private var thumbnailSize: CGFloat {
        horizontalSizeClass == .regular ? 200 : 120
    }

    var body: some View {
        Group {
            if isLoading && images.isEmpty {
                loadingView
            } else if images.isEmpty {
                emptyStateView
            } else {
                imageGrid
            }
        }
        .navigationTitle(gallery.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    // Share button
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(images.isEmpty)

                    // Display Mode button
                    Button {
                        showingSlideshow = true
                    } label: {
                        Image(systemName: "play.rectangle.fill")
                    }
                    .disabled(images.isEmpty)

                    PhotosPicker(selection: $selectedPhotos, matching: .images) {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            SlideshowView(gallery: gallery)
        }
        .overlay {
            if isImporting {
                importingOverlay
            }
        }
        .task {
            await loadContent()
        }
        .refreshable {
            await loadContent()
        }
        .onChange(of: selectedPhotos) { _, newValue in
            if !newValue.isEmpty {
                Task {
                    await importPhotos(newValue)
                    selectedPhotos = []
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareGallerySheet(gallery: gallery, images: images)
        }
        .alert("Delete Image", isPresented: $showingDeleteConfirmation, presenting: imageToDelete) { image in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteImage(image)
                }
            }
        } message: { image in
            Text("Are you sure you want to delete \"\(image.filename)\"?")
        }
    }

    // MARK: - Image Grid

    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: horizontalSizeClass == .regular ? 12 : 8) {
                ForEach(images) { image in
                    ArtworkThumbnailView(image: image, size: thumbnailSize)
                        .contextMenu {
                            Button(role: .destructive) {
                                imageToDelete = image
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(horizontalSizeClass == .regular ? 20 : 16)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading images...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Images")
                .font(.title2)
                .fontWeight(.medium)

            Text("Add photos to your gallery\nto get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PhotosPicker(selection: $selectedPhotos, matching: .images) {
                Label("Add Photos", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isImporting)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Importing Overlay

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Importing photos...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            GallerySettingsView(
                settings: $settings,
                galleryName: gallery.name,
                onSave: {
                    Task {
                        try? await galleryManager.saveSettings(settings, for: gallery)
                    }
                }
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Data Loading

    private func loadContent() async {
        isLoading = true

        do {
            async let loadedImages = galleryManager.loadImages(for: gallery)
            async let loadedSettings = galleryManager.loadSettings(for: gallery)

            images = try await loadedImages
            settings = try await loadedSettings
        } catch {
            // Handle error - images will remain empty
        }

        isLoading = false
    }

    // MARK: - Photo Import

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isImporting = true

        var tempURLs: [URL] = []
        let tempDirectory = FileManager.default.temporaryDirectory

        for item in items {
            do {
                // Load the image data
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }

                // Create a temporary file with the original filename if available
                let filename = item.itemIdentifier ?? UUID().uuidString
                let sanitizedFilename = sanitizeFilename(filename)
                let tempURL = tempDirectory.appendingPathComponent(sanitizedFilename)

                // Write data to temp file
                try data.write(to: tempURL)
                tempURLs.append(tempURL)
            } catch {
                // Skip this photo and continue with others
                continue
            }
        }

        // Add images to gallery
        if !tempURLs.isEmpty {
            do {
                let addedImages = try await galleryManager.addImages(from: tempURLs, to: gallery)
                images.append(contentsOf: addedImages)
                images.sort { $0.sortKey < $1.sortKey }
            } catch {
                // Error adding images
            }
        }

        // Clean up temp files
        for url in tempURLs {
            try? FileManager.default.removeItem(at: url)
        }

        isImporting = false
    }

    private func sanitizeFilename(_ identifier: String) -> String {
        // Create a safe filename from the identifier
        let baseName = identifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        // Ensure it has an image extension
        if !baseName.lowercased().hasSuffix(".jpg") &&
           !baseName.lowercased().hasSuffix(".jpeg") &&
           !baseName.lowercased().hasSuffix(".png") &&
           !baseName.lowercased().hasSuffix(".heic") {
            return baseName + ".jpg"
        }

        return baseName
    }

    // MARK: - Image Deletion

    private func deleteImage(_ image: ArtworkImage) async {
        do {
            try await galleryManager.deleteImage(image, from: gallery)
            images.removeAll { $0.id == image.id }
        } catch {
            // Error deleting image
        }
    }
}

#Preview {
    NavigationStack {
        GalleryDetailView(gallery: Gallery(
            name: "Sample Gallery",
            folderURL: URL(fileURLWithPath: "/tmp/sample")
        ))
    }
}
