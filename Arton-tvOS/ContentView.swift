import SwiftUI
import ArtonCore

struct ContentView: View {
    @Binding var deepLinkGalleryID: String?
    @StateObject private var galleryManager = GalleryManager.shared
    @StateObject private var displaySettings = DisplaySettingsManager.shared
    @State private var selectedGallery: Gallery?
    @State private var selectedSharedGallery: SharedGallery?
    @State private var showingSettings = false
    @State private var selectedSection: ContentSection = .myGalleries
    @State private var isLoadingDeepLink = false

    enum ContentSection: String, CaseIterable {
        case myGalleries = "My Galleries"
        case explore = "Explore"
    }

    init(deepLinkGalleryID: Binding<String?> = .constant(nil)) {
        self._deepLinkGalleryID = deepLinkGalleryID
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(ContentSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 80)
                .padding(.bottom, 40)

                // Content
                Group {
                    switch selectedSection {
                    case .myGalleries:
                        myGalleriesContent
                    case .explore:
                        exploreContent
                    }
                }
            }
            .navigationTitle("Arton")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(item: $selectedGallery) { gallery in
                SlideshowView(gallery: gallery)
            }
            .navigationDestination(item: $selectedSharedGallery) { gallery in
                SharedGalleryDetailView(gallery: gallery)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            await galleryManager.loadGalleries()
            await displaySettings.loadSettings()
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
        selectedSection = .explore

        Task {
            do {
                if let gallery = try await CloudKitSharingService.shared.fetchGallery(id: galleryID) {
                    selectedSharedGallery = gallery
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

            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(2)

                Text("Opening gallery...")
                    .font(.headline)
            }
            .padding(48)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - My Galleries

    private var myGalleriesContent: some View {
        GalleryPickerView(
            galleries: galleryManager.galleries,
            isLoading: galleryManager.isLoading,
            onSelect: { gallery in
                selectedGallery = gallery
            }
        )
    }

    // MARK: - Explore

    private var exploreContent: some View {
        ExploreView()
    }
}

#Preview {
    ContentView()
}
