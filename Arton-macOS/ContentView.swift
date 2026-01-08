import SwiftUI
import ArtonCore

struct ContentView: View {
    @StateObject private var galleryManager = GalleryManager.shared
    @State private var selectedGallery: Gallery?
    @State private var showingNewGallerySheet = false
    @State private var newGalleryName = ""
    @State private var galleryToDelete: Gallery?
    @State private var showingDeleteConfirmation = false
    @State private var renamingGallery: Gallery?
    @State private var renameText = ""

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
                    if selectedGallery?.id == gallery.id {
                        selectedGallery = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { gallery in
            Text("Are you sure you want to delete \"\(gallery.name)\"? This will permanently remove the gallery and all its images.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedGallery) {
            Section {
                ForEach(galleryManager.galleries) { gallery in
                    galleryRow(gallery)
                        .tag(gallery)
                }
            } header: {
                HStack {
                    Text("Galleries")
                    Spacer()
                    if galleryManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
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
        if let gallery = selectedGallery {
            GalleryDetailView(gallery: gallery)
        } else {
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

            Text("Choose a gallery from the sidebar to view and manage its images.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
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
                selectedGallery = gallery
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
