import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ArtworkProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArtworkEntry {
        ArtworkEntry(date: Date(), galleryName: "Gallery", imagePath: nil, imageCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArtworkEntry) -> Void) {
        let entry = ArtworkEntry(date: Date(), galleryName: "My Gallery", imagePath: nil, imageCount: 12)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtworkEntry>) -> Void) {
        Task {
            let entry = await loadRandomArtwork()

            // Update every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func loadRandomArtwork() async -> ArtworkEntry {
        // Try to find galleries in the shared container
        let fileManager = FileManager.default

        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.arton.galleries") else {
            return ArtworkEntry(date: Date(), galleryName: "No iCloud", imagePath: nil, imageCount: 0)
        }

        let galleriesURL = containerURL.appendingPathComponent("Documents/Arton/Galleries")

        guard let galleries = try? fileManager.contentsOfDirectory(at: galleriesURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return ArtworkEntry(date: Date(), galleryName: "No Galleries", imagePath: nil, imageCount: 0)
        }

        let galleryFolders = galleries.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        guard !galleryFolders.isEmpty else {
            return ArtworkEntry(date: Date(), galleryName: "No Galleries", imagePath: nil, imageCount: 0)
        }

        // Pick a random gallery
        let randomGallery = galleryFolders.randomElement()!
        let galleryName = randomGallery.lastPathComponent

        // Get images in the gallery
        let supportedExtensions = ["jpg", "jpeg", "png", "heic", "gif"]
        guard let contents = try? fileManager.contentsOfDirectory(at: randomGallery, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return ArtworkEntry(date: Date(), galleryName: galleryName, imagePath: nil, imageCount: 0)
        }

        let images = contents.filter { url in
            supportedExtensions.contains(url.pathExtension.lowercased())
        }

        guard !images.isEmpty else {
            return ArtworkEntry(date: Date(), galleryName: galleryName, imagePath: nil, imageCount: 0)
        }

        // Pick a random image
        let randomImage = images.randomElement()!

        return ArtworkEntry(
            date: Date(),
            galleryName: galleryName,
            imagePath: randomImage.path,
            imageCount: images.count
        )
    }
}

// MARK: - Timeline Entry

struct ArtworkEntry: TimelineEntry {
    let date: Date
    let galleryName: String
    let imagePath: String?
    let imageCount: Int
}

// MARK: - Widget View

struct ArtonWidgetEntryView: View {
    var entry: ArtworkProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                if let imagePath = entry.imagePath,
                   let uiImage = loadImage(from: imagePath, size: geometry.size) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    // Placeholder gradient
                    LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // Overlay with gallery info
                VStack {
                    Spacer()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.galleryName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)

                            if family != .systemSmall && entry.imageCount > 0 {
                                Text("\(entry.imageCount) images")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .shadow(radius: 2)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private func loadImage(from path: String, size: CGSize) -> UIImage? {
        let url = URL(fileURLWithPath: path)

        // Generate thumbnail for performance
        let maxDimension = max(size.width, size.height) * UIScreen.main.scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: path)
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Widget Configuration

struct ArtonWidget: Widget {
    let kind: String = "ArtonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArtworkProvider()) { entry in
            ArtonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arton Gallery")
        .description("Display random artwork from your galleries.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct ArtonWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArtonWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    ArtonWidget()
} timeline: {
    ArtworkEntry(date: .now, galleryName: "Nature", imagePath: nil, imageCount: 24)
    ArtworkEntry(date: .now, galleryName: "Abstract", imagePath: nil, imageCount: 12)
}
