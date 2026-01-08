import XCTest
@testable import ArtonCore

final class ArtonCoreTests: XCTestCase {

    // MARK: - Gallery Tests

    func testGalleryInitialization() {
        let url = URL(fileURLWithPath: "/test/gallery")
        let gallery = Gallery(name: "Test Gallery", folderURL: url)

        XCTAssertEqual(gallery.name, "Test Gallery")
        XCTAssertEqual(gallery.folderURL, url)
        XCTAssertNil(gallery.cachedImageCount)
    }

    func testGalleryEquality() {
        let url = URL(fileURLWithPath: "/test/gallery")
        let gallery1 = Gallery(id: UUID(), name: "Test", folderURL: url)
        var gallery2 = gallery1
        gallery2.name = "Different Name"

        // Same ID means equal
        XCTAssertEqual(gallery1, gallery2)
    }

    // MARK: - GallerySettings Tests

    func testGallerySettingsDefaults() {
        let settings = GallerySettings()

        XCTAssertEqual(settings.displayOrder, .serial)
        XCTAssertEqual(settings.transitionEffect, .fade)
        XCTAssertEqual(settings.displayInterval, 30)
        XCTAssertNil(settings.transitionDuration)
    }

    func testGallerySettingsEffectiveTransitionDuration() {
        var settings = GallerySettings()

        // Default fade duration
        XCTAssertEqual(settings.effectiveTransitionDuration, 1.0)

        // Custom duration overrides default
        settings.transitionDuration = 2.5
        XCTAssertEqual(settings.effectiveTransitionDuration, 2.5)

        // None effect has zero duration
        settings.transitionEffect = .none
        settings.transitionDuration = nil
        XCTAssertEqual(settings.effectiveTransitionDuration, 0)
    }

    func testGallerySettingsCodable() throws {
        let original = GallerySettings(
            displayOrder: .random,
            transitionEffect: .slide,
            transitionDuration: 0.8,
            displayInterval: 60
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GallerySettings.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - ArtworkImage Tests

    func testArtworkImageSupportedExtensions() {
        XCTAssertTrue(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.jpg")))
        XCTAssertTrue(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.JPEG")))
        XCTAssertTrue(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.png")))
        XCTAssertTrue(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.heic")))
        XCTAssertTrue(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.gif")))

        XCTAssertFalse(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.webp")))
        XCTAssertFalse(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.bmp")))
        XCTAssertFalse(ArtworkImage.isSupportedImage(url: URL(fileURLWithPath: "/test.txt")))
    }

    func testArtworkImageStableID() {
        let galleryURL = URL(fileURLWithPath: "/galleries/nature")
        let imageURL = URL(fileURLWithPath: "/galleries/nature/sunset.jpg")

        let image1 = ArtworkImage(fileURL: imageURL, galleryURL: galleryURL)
        let image2 = ArtworkImage(fileURL: imageURL, galleryURL: galleryURL)

        // Same path should produce same ID
        XCTAssertEqual(image1.id, image2.id)
    }

    // MARK: - DisplaySettings Tests

    func testDisplaySettingsDefaults() {
        let settings = DisplaySettings()

        XCTAssertEqual(settings.canvasColor, .black)
        XCTAssertEqual(settings.canvasPadding, 0)
        XCTAssertNil(settings.selectedGalleryID)
    }

    func testDisplaySettingsPaddingClamping() {
        let tooHigh = DisplaySettings(canvasPadding: 0.5)
        XCTAssertEqual(tooHigh.canvasPadding, 0.25)

        let tooLow = DisplaySettings(canvasPadding: -0.1)
        XCTAssertEqual(tooLow.canvasPadding, 0)

        let valid = DisplaySettings(canvasPadding: 0.15)
        XCTAssertEqual(valid.canvasPadding, 0.15)
    }

    // MARK: - DisplayOrder Tests

    func testDisplayOrderDisplayNames() {
        XCTAssertEqual(DisplayOrder.serial.displayName, "In Order")
        XCTAssertEqual(DisplayOrder.random.displayName, "Shuffle")
        XCTAssertEqual(DisplayOrder.pingPong.displayName, "Back & Forth")
    }

    // MARK: - TransitionEffect Tests

    func testTransitionEffectDefaultDurations() {
        XCTAssertEqual(TransitionEffect.none.defaultDuration, 0)
        XCTAssertEqual(TransitionEffect.fade.defaultDuration, 1.0)
        XCTAssertEqual(TransitionEffect.dissolve.defaultDuration, 1.0)
        XCTAssertEqual(TransitionEffect.slide.defaultDuration, 0.5)
        XCTAssertEqual(TransitionEffect.push.defaultDuration, 0.5)
    }
}
