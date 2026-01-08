import SwiftUI
import ArtonCore

struct ContentView: View {
    @Binding var deepLinkGalleryID: String?
    @State private var selectedTab: Tab = .galleries
    @State private var deepLinkSharedGallery: SharedGallery?
    @State private var isLoadingDeepLink = false

    enum Tab {
        case galleries
        case explore
    }

    init(deepLinkGalleryID: Binding<String?> = .constant(nil)) {
        self._deepLinkGalleryID = deepLinkGalleryID
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GalleriesTab()
                .tabItem {
                    Label("My Galleries", systemImage: "photo.on.rectangle")
                }
                .tag(Tab.galleries)

            NavigationStack {
                ExploreView()
                    .navigationDestination(item: $deepLinkSharedGallery) { gallery in
                        SharedGalleryDetailView(gallery: gallery)
                    }
            }
            .tabItem {
                Label("Explore", systemImage: "globe")
            }
            .tag(Tab.explore)
        }
        .onChange(of: deepLinkGalleryID) { _, newValue in
            if let galleryID = newValue {
                handleDeepLink(galleryID: galleryID)
            }
        }
        .overlay {
            if isLoadingDeepLink {
                deepLinkLoadingOverlay
            }
        }
    }

    private func handleDeepLink(galleryID: String) {
        isLoadingDeepLink = true
        selectedTab = .explore

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
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Opening gallery...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Galleries Tab

struct GalleriesTab: View {
    @StateObject private var galleryManager = GalleryManager.shared
    @State private var showingNewGallerySheet = false
    @State private var newGalleryName = ""
    @State private var galleryToDelete: Gallery?
    @State private var showingDeleteConfirmation = false
    @State private var selectedGallery: Gallery?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadNavigationView
            } else {
                iPhoneNavigationView
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
                    if selectedGallery?.id == gallery.id {
                        selectedGallery = nil
                    }
                }
            }
        } message: { gallery in
            Text("Are you sure you want to delete \"\(gallery.name)\"? This will permanently remove all images in the gallery.")
        }
    }

    // MARK: - iPad Navigation (Split View)

    private var iPadNavigationView: some View {
        NavigationSplitView {
            sidebarContent
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
        } detail: {
            if let gallery = selectedGallery {
                GalleryDetailView(gallery: gallery)
            } else {
                ContentUnavailableView(
                    "Select a Gallery",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Choose a gallery from the sidebar to view its contents")
                )
            }
        }
    }

    // MARK: - iPhone Navigation (Stack)

    private var iPhoneNavigationView: some View {
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
    }

    // MARK: - Sidebar Content (iPad)

    private var sidebarContent: some View {
        Group {
            if galleryManager.isLoading && galleryManager.galleries.isEmpty {
                loadingView
            } else if galleryManager.galleries.isEmpty {
                emptyStateView
            } else {
                sidebarList
            }
        }
    }

    private var sidebarList: some View {
        List(selection: $selectedGallery) {
            ForEach(galleryManager.galleries) { gallery in
                NavigationLink(value: gallery) {
                    GalleryRowView(gallery: gallery, thumbnailSize: 100)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        galleryToDelete = gallery
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            await galleryManager.loadGalleries()
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
