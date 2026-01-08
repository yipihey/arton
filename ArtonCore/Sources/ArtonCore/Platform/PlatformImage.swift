#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

import Foundation

/// Platform-agnostic image utilities
public enum ImageUtilities {
    /// Load an image from a file URL
    public static func loadImage(from url: URL) -> PlatformImage? {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(contentsOf: url)
        #endif
    }

    /// Get image dimensions without fully loading the image
    public static func imageDimensions(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        // Check for orientation and swap if needed
        if let orientation = properties[kCGImagePropertyOrientation] as? Int,
           orientation >= 5 && orientation <= 8 {
            return CGSize(width: height, height: width)
        }

        return CGSize(width: width, height: height)
    }

    /// Generate a thumbnail image
    public static func generateThumbnail(
        from url: URL,
        maxSize: CGFloat
    ) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #endif
    }
}
