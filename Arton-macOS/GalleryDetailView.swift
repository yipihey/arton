import SwiftUI
import UniformTypeIdentifiers
import ArtonCore

struct GalleryDetailView: View {
    let gallery: Gallery

    @StateObject private var galleryManager = GalleryManager.shared
    @State private var images: [ArtworkImage] = []
    @State private var selectedImages: Set<ArtworkImage.ID> = []
    @State private var isLoading = true
    @State private var isDropTargeted = false
    @State private var showingSettings = false
    @State private var gallerySettings = GallerySettings.default
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if images.isEmpty {
                emptyGalleryView
            } else {
                imageGridView
            }
        }
        .navigationTitle(gallery.name)
        .navigationSubtitle("\(images.count) image\(images.count == 1 ? "" : "s")")
        .toolbar {
            toolbarContent
        }
        .task(id: gallery.id) {
            await loadGalleryContent()
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
        .onDeleteCommand {
            deleteSelectedImages()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading images...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Gallery View

    private var emptyGalleryView: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                    )

                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(isDropTargeted ? .primary : .secondary)

                    Text("Drop images here")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("or click the Add button to browse")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Button("Add Images...") {
                        showFilePicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding(40)
            }
            .frame(maxWidth: 400, maxHeight: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Image Grid View

    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(images) { image in
                    imageCell(image)
                }
            }
            .padding(20)
        }
        .background(
            isDropTargeted ?
            Color.accentColor.opacity(0.1) :
            Color.clear
        )
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
    }

    private func imageCell(_ image: ArtworkImage) -> some View {
        let isSelected = selectedImages.contains(image.id)

        return ArtworkThumbnailView(image: image, size: 150, showFilename: true)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                }
            }
            .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 4)
            .onTapGesture {
                handleImageTap(image)
            }
            .contextMenu {
                imageContextMenu(image)
            }
    }

    private var dropOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .padding(8)

            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.primary)

                Text("Drop to add images")
                    .font(.headline)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func imageContextMenu(_ image: ArtworkImage) -> some View {
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([image.fileURL])
        }

        Divider()

        Button("Delete", role: .destructive) {
            deleteImage(image)
        }

        if selectedImages.count > 1 && selectedImages.contains(image.id) {
            Button("Delete Selected (\(selectedImages.count))", role: .destructive) {
                deleteSelectedImages()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showFilePicker()
            } label: {
                Label("Add Images", systemImage: "plus")
            }
            .help("Add images to this gallery")

            Button {
                showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Gallery settings")

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: gallery.folderURL.path)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .help("Reveal gallery folder in Finder")
        }

        ToolbarItem(placement: .automatic) {
            if !selectedImages.isEmpty {
                Button(role: .destructive) {
                    deleteSelectedImages()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .help("Delete selected images")
            }
        }
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        NavigationStack {
            GallerySettingsView(
                settings: $gallerySettings,
                galleryName: gallery.name,
                onSave: {
                    Task {
                        try? await galleryManager.saveSettings(gallerySettings, for: gallery)
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
        .frame(minWidth: 400, minHeight: 350)
    }

    // MARK: - Actions

    private func loadGalleryContent() async {
        isLoading = true
        selectedImages.removeAll()

        do {
            images = try await galleryManager.loadImages(for: gallery)
            gallerySettings = try await galleryManager.loadSettings(for: gallery)
        } catch {
            errorMessage = "Failed to load gallery: \(error.localizedDescription)"
            images = []
        }

        isLoading = false
    }

    private func handleImageTap(_ image: ArtworkImage) {
        if NSEvent.modifierFlags.contains(.command) {
            // Command-click: toggle selection
            if selectedImages.contains(image.id) {
                selectedImages.remove(image.id)
            } else {
                selectedImages.insert(image.id)
            }
        } else if NSEvent.modifierFlags.contains(.shift), let lastSelected = selectedImages.first {
            // Shift-click: range selection
            if let startIndex = images.firstIndex(where: { $0.id == lastSelected }),
               let endIndex = images.firstIndex(where: { $0.id == image.id }) {
                let range = min(startIndex, endIndex)...max(startIndex, endIndex)
                for index in range {
                    selectedImages.insert(images[index].id)
                }
            }
        } else {
            // Regular click: single selection
            selectedImages = [image.id]
        }
    }

    private func showFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .gif]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Select images to add to \"\(gallery.name)\""
        panel.prompt = "Add Images"

        panel.begin { response in
            if response == .OK {
                let urls = panel.urls
                Task {
                    await addImages(from: urls)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        Task {
            var urls: [URL] = []

            for provider in providers {
                // Try to get file URL first
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    if let url = await loadFileURL(from: provider) {
                        urls.append(url)
                    }
                }
            }

            if !urls.isEmpty {
                await addImages(from: urls)
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func addImages(from urls: [URL]) async {
        do {
            let addedImages = try await galleryManager.addImages(from: urls, to: gallery)

            // Reload to get proper sorting
            images = try await galleryManager.loadImages(for: gallery)

            // Select newly added images
            selectedImages = Set(addedImages.map { $0.id })
        } catch {
            errorMessage = "Failed to add images: \(error.localizedDescription)"
        }
    }

    private func deleteImage(_ image: ArtworkImage) {
        Task {
            do {
                try await galleryManager.deleteImage(image, from: gallery)
                images.removeAll { $0.id == image.id }
                selectedImages.remove(image.id)
            } catch {
                errorMessage = "Failed to delete image: \(error.localizedDescription)"
            }
        }
    }

    private func deleteSelectedImages() {
        guard !selectedImages.isEmpty else { return }

        let imagesToDelete = images.filter { selectedImages.contains($0.id) }

        Task {
            for image in imagesToDelete {
                do {
                    try await galleryManager.deleteImage(image, from: gallery)
                    images.removeAll { $0.id == image.id }
                } catch {
                    errorMessage = "Failed to delete some images: \(error.localizedDescription)"
                    break
                }
            }
            selectedImages.removeAll()
        }
    }
}

#Preview {
    GalleryDetailView(
        gallery: Gallery(
            name: "Test Gallery",
            folderURL: URL(fileURLWithPath: "/tmp/test")
        )
    )
}
