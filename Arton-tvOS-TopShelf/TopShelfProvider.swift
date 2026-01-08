import TVServices

/// Top Shelf content provider for Arton tvOS app
/// Displays gallery posters in the Top Shelf when the app is focused
class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        Task {
            let content = await loadGalleryContent()
            completionHandler(content)
        }
    }

    private func loadGalleryContent() async -> TVTopShelfContent? {
        let fileManager = FileManager.default

        // Get iCloud container
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.arton.galleries") else {
            return createPlaceholderContent(message: "Sign in to iCloud to see your galleries")
        }

        let galleriesURL = containerURL.appendingPathComponent("Documents/Arton/Galleries")

        // Get gallery folders
        guard let galleries = try? fileManager.contentsOfDirectory(at: galleriesURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return createPlaceholderContent(message: "No galleries found")
        }

        let galleryFolders = galleries.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        guard !galleryFolders.isEmpty else {
            return createPlaceholderContent(message: "Create galleries in the Arton app")
        }

        // Create sectioned content with gallery items
        var items: [TVTopShelfSectionedItem] = []

        for galleryURL in galleryFolders.prefix(10) {
            let galleryName = galleryURL.lastPathComponent

            // Find poster image (first alphabetically)
            if let posterURL = findPosterImage(in: galleryURL) {
                let item = TVTopShelfSectionedItem(identifier: galleryURL.path)
                item.title = galleryName

                // Set the image URL for the poster
                item.setImageURL(posterURL, for: .screenScale1x)
                item.setImageURL(posterURL, for: .screenScale2x)

                // Create display action to open the gallery
                let displayAction = TVTopShelfAction(url: createGalleryURL(galleryName: galleryName))
                item.displayAction = displayAction
                item.playAction = displayAction

                items.append(item)
            }
        }

        guard !items.isEmpty else {
            return createPlaceholderContent(message: "Add images to your galleries")
        }

        // Create sectioned content
        let section = TVTopShelfItemCollection(items: items)
        section.title = "Your Galleries"

        let content = TVTopShelfSectionedContent(sections: [section])
        return content
    }

    private func findPosterImage(in galleryURL: URL) -> URL? {
        let fileManager = FileManager.default
        let supportedExtensions = ["jpg", "jpeg", "png", "heic", "gif"]

        guard let contents = try? fileManager.contentsOfDirectory(at: galleryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return nil
        }

        let images = contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

        return images.first
    }

    private func createGalleryURL(galleryName: String) -> URL {
        // Create a deep link URL to open the specific gallery
        var components = URLComponents()
        components.scheme = "arton"
        components.host = "gallery"
        components.queryItems = [URLQueryItem(name: "name", value: galleryName)]
        return components.url ?? URL(string: "arton://")!
    }

    private func createPlaceholderContent(message: String) -> TVTopShelfContent {
        // Create sectioned content with a placeholder message
        let item = TVTopShelfSectionedItem(identifier: "placeholder")
        item.title = message

        let section = TVTopShelfItemCollection(items: [item])
        section.title = "Arton"

        let content = TVTopShelfSectionedContent(sections: [section])
        return content
    }
}
