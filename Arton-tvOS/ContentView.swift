import SwiftUI
import ArtonCore

struct ContentView: View {
    @StateObject private var galleryManager = GalleryManager.shared
    @StateObject private var displaySettings = DisplaySettingsManager.shared
    @State private var selectedGallery: Gallery?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            GalleryPickerView(
                galleries: galleryManager.galleries,
                isLoading: galleryManager.isLoading,
                onSelect: { gallery in
                    selectedGallery = gallery
                }
            )
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .task {
            await galleryManager.loadGalleries()
            await displaySettings.loadSettings()
        }
    }
}

#Preview {
    ContentView()
}
