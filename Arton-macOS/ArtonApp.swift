import SwiftUI
import ArtonCore

@main
struct ArtonApp: App {
    @State private var deepLinkGalleryID: String?

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkGalleryID: $deepLinkGalleryID)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .windowResizability(.contentSize)
    }

    private func handleDeepLink(_ url: URL) {
        // Handle arton://gallery/{id} URLs
        guard url.scheme == "arton",
              url.host == "gallery" else {
            return
        }

        // Extract gallery ID from path
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let galleryID = pathComponents.first else {
            return
        }

        deepLinkGalleryID = galleryID
    }
}
