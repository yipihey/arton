import SwiftUI
import ArtonCore

struct ContentView: View {
    @StateObject private var galleryManager = GalleryManager.shared
    @State private var showingNewGallerySheet = false
    @State private var newGalleryName = ""
    @State private var galleryToDelete: Gallery?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if galleryManager.isLoading && galleryManager.galleries.isEmpty {
                    loadingView
                } else if galleryManager.galleries.isEmpty {
                    emptyStateView
                } else {
                    galleryList
                }
            }
            .navigationTitle("Galleries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newGalleryName = ""
                        showingNewGallerySheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await galleryManager.loadGalleries()
            }
        }
        .task {
            await galleryManager.loadGalleries()
        }
        .sheet(isPresented: $showingNewGallerySheet) {
            newGallerySheet
        }
        .alert("Delete Gallery", isPresented: $showingDeleteConfirmation, presenting: galleryToDelete) { gallery in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await galleryManager.deleteGallery(gallery)
                }
            }
        } message: { gallery in
            Text("Are you sure you want to delete \"\(gallery.name)\"? This will permanently remove all images in the gallery.")
        }
    }

    // MARK: - Gallery List

    private var galleryList: some View {
        List {
            ForEach(galleryManager.galleries) { gallery in
                NavigationLink {
                    GalleryDetailView(gallery: gallery)
                } label: {
                    GalleryRowView(gallery: gallery, thumbnailSize: 80)
                }
            }
            .onDelete(perform: deleteGalleries)
        }
        .listStyle(.plain)
    }

    private func deleteGalleries(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        galleryToDelete = galleryManager.galleries[index]
        showingDeleteConfirmation = true
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading galleries...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("No Galleries")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a gallery to start curating\nyour art collection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                newGalleryName = ""
                showingNewGallerySheet = true
            } label: {
                Label("Create Gallery", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - New Gallery Sheet

    private var newGallerySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Gallery Name", text: $newGalleryName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Choose a name for your new gallery. This will be the folder name in iCloud Drive.")
                }
            }
            .navigationTitle("New Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNewGallerySheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGallery()
                    }
                    .disabled(newGalleryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createGallery() {
        let name = newGalleryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        Task {
            do {
                _ = try await galleryManager.createGallery(named: name)
                showingNewGallerySheet = false
            } catch {
                // Error is captured in galleryManager.error
            }
        }
    }
}

#Preview {
    ContentView()
}
