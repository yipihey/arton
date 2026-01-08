import SwiftUI

public struct ArtworkThumbnailView: View {
    let image: ArtworkImage
    var size: CGFloat = 150
    var showFilename: Bool = false

    @State private var thumbnail: PlatformImage?

    public init(image: ArtworkImage, size: CGFloat = 150, showFilename: Bool = false) {
        self.image = image
        self.size = size
        self.showFilename = showFilename
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Thumbnail or placeholder
            Group {
                if let thumbnail = thumbnail {
                    #if canImport(UIKit)
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #elseif canImport(AppKit)
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    // Placeholder while loading
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: size * 0.3))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipped()

            // Cloud download overlay if not downloaded
            if !image.isDownloaded {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .padding(8)
                    }
                    Spacer()
                }
            }

            // Filename overlay with gradient
            if showFilename {
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: size * 0.4)

                    Text(image.filename)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            thumbnail = await ThumbnailCache.shared.thumbnail(for: image.fileURL, size: size)
        }
    }
}
