import WidgetKit
import SwiftUI
import ArtonCore

// MARK: - Timeline Provider

struct ArtworkProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArtworkEntry {
        ArtworkEntry(date: Date(), data: WidgetArtworkData(galleryName: "Gallery", imagePath: nil, imageCount: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (ArtworkEntry) -> Void) {
        let entry = ArtworkEntry(
            date: Date(),
            data: WidgetArtworkData(galleryName: "My Gallery", imagePath: nil, imageCount: 12)
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtworkEntry>) -> Void) {
        Task {
            let data = await WidgetHelper.loadRandomArtwork()
            let entry = ArtworkEntry(date: Date(), data: data)

            // Update every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Timeline Entry

struct ArtworkEntry: TimelineEntry {
    let date: Date
    let data: WidgetArtworkData
}

// MARK: - Widget View

struct ArtonWidgetEntryView: View {
    var entry: ArtworkProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        GeometryReader { geometry in
            WidgetArtworkView(
                galleryName: entry.data.galleryName,
                imagePath: entry.data.imagePath,
                imageCount: entry.data.imageCount,
                showImageCount: family != .systemSmall,
                size: geometry.size
            )
        }
        .containerBackground(for: .widget) {
            Color.black
        }
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
    ArtworkEntry(date: .now, data: WidgetArtworkData(galleryName: "Nature", imagePath: nil, imageCount: 24))
    ArtworkEntry(date: .now, data: WidgetArtworkData(galleryName: "Abstract", imagePath: nil, imageCount: 12))
}
