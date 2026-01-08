import SwiftUI
import ArtonCore

enum SidebarSection: Hashable {
    case gallery(Gallery)
    case explore
    case settings
}

struct ContentView: View {
    @Binding var deepLinkGalleryID: String?
    @StateObject private var galleryManager = GalleryManager.shared
    @State private var selectedSection: SidebarSection?
    @State private var showingNewGallerySheet = false
    @State private var newGalleryName = ""
    @State private var galleryToDelete: Gallery?
    @State private var showingDeleteConfirmation = false
    @State private var renamingGallery: Gallery?
    @State private var renameText = ""
    @State private var deepLinkSharedGallery: SharedGallery?
    @State private var isLoadingDeepLink = false

    init(deepLinkGalleryID: Binding<String?> = .constant(nil)) {
        self._deepLinkGalleryID = deepLinkGalleryID
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            detailView
        }
        .frame(minWidth: 800, minHeight: 600)
        .task {
            await galleryManager.loadGalleries()
        }
        .sheet(isPresented: $showingNewGallerySheet) {
            newGallerySheet
        }
        .confirmationDialog(
            "Delete Gallery",
            isPresented: $showingDeleteConfirmation,
            presenting: galleryToDelete
        ) { gallery in
            Button("Delete \"\(gallery.name)\"", role: .destructive) {
                Task {
                    try? await galleryManager.deleteGallery(gallery)
                    if case .gallery(let selected) = selectedSection, selected.id == gallery.id {
                        selectedSection = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { gallery in
            Text("Are you sure you want to delete \"\(gallery.name)\"? This will permanently remove the gallery and all its images.")
        }
        .onChange(of: deepLinkGalleryID) { _, newValue in
            if let galleryID = newValue {
                handleDeepLink(galleryID: galleryID)
            }
        }
        .sheet(item: $deepLinkSharedGallery) { gallery in
            NavigationStack {
                SharedGalleryDetailView(gallery: gallery)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                deepLinkSharedGallery = nil
                            }
                        }
                    }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .overlay {
            if isLoadingDeepLink {
                deepLinkLoadingOverlay
            }
        }
    }

    private func handleDeepLink(galleryID: String) {
        isLoadingDeepLink = true

        Task {
            do {
                if let gallery = try await CloudKitSharingService.shared.fetchGallery(id: galleryID) {
                    deepLinkSharedGallery = gallery
                }
            } catch {
                // Gallery not found or error - ignore
            }
            isLoadingDeepLink = false
            deepLinkGalleryID = nil
        }
    }

    private var deepLinkLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Opening gallery...")
                    .font(.headline)
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            // My Galleries section
            Section {
                ForEach(galleryManager.galleries) { gallery in
                    galleryRow(gallery)
                        .tag(SidebarSection.gallery(gallery))
                }
            } header: {
                HStack {
                    Text("My Galleries")
                    Spacer()
                    if galleryManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            }

            // Explore section
            Section {
                Label("Explore", systemImage: "globe")
                    .tag(SidebarSection.explore)
            } header: {
                Text("Community")
            }

            // Settings section
            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarSection.settings)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newGalleryName = ""
                    showingNewGallerySheet = true
                } label: {
                    Label("New Gallery", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await galleryManager.loadGalleries()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func galleryRow(_ gallery: Gallery) -> some View {
        HStack {
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(.secondary)

            if renamingGallery?.id == gallery.id {
                TextField("Gallery Name", text: $renameText, onCommit: {
                    commitRename(gallery)
                })
                .textFieldStyle(.plain)
                .onExitCommand {
                    renamingGallery = nil
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(gallery.name)
                        .lineLimit(1)

                    if let count = gallery.cachedImageCount {
                        Text("\(count) image\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contextMenu {
            Button("Rename...") {
                renameText = gallery.name
                renamingGallery = gallery
            }

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: gallery.folderURL.path)
            }

            Divider()

            Button("Delete...", role: .destructive) {
                galleryToDelete = gallery
                showingDeleteConfirmation = true
            }
        }
    }

    private func commitRename(_ gallery: Gallery) {
        let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != gallery.name else {
            renamingGallery = nil
            return
        }

        Task {
            try? await galleryManager.renameGallery(gallery, to: trimmedName)
            renamingGallery = nil
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .gallery(let gallery):
            GalleryDetailView(gallery: gallery)
        case .explore:
            ExploreView()
        case .settings:
            AppSettingsView()
        case .none:
            emptyDetailView
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("Select a gallery")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Choose a gallery from the sidebar to view and manage its images,\nor explore publicly shared galleries.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - New Gallery Sheet

    private var newGallerySheet: some View {
        VStack(spacing: 20) {
            Text("New Gallery")
                .font(.headline)

            TextField("Gallery Name", text: $newGalleryName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    createNewGallery()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    showingNewGallerySheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createNewGallery()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newGalleryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 350)
    }

    private func createNewGallery() {
        let trimmedName = newGalleryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        Task {
            do {
                let gallery = try await galleryManager.createGallery(named: trimmedName)
                selectedSection = .gallery(gallery)
                showingNewGallerySheet = false
            } catch {
                // Handle error - could show an alert here
                print("Failed to create gallery: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
