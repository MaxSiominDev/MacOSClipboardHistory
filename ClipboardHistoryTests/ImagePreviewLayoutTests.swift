import XCTest
import CoreGraphics
@testable import ClipboardHistory

final class ImagePreviewLayoutTests: XCTestCase {
    private let screen = CGSize(width: 1000, height: 1000)

    func testImageSmallerThanCapKeepsNaturalSize() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: 400, height: 300), screen: screen)
        XCTAssertEqual(size, CGSize(width: 400, height: 300))
    }

    func testImageExactlyAtCapKeepsNaturalSize() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: 800, height: 800), screen: screen)
        XCTAssertEqual(size, CGSize(width: 800, height: 800))
    }

    func testWideImageShrinksByWidth() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: 1600, height: 800), screen: screen)
        XCTAssertEqual(size, CGSize(width: 800, height: 400))
    }

    func testTallImageShrinksByHeight() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: 800, height: 1600), screen: screen)
        XCTAssertEqual(size, CGSize(width: 400, height: 800))
    }

    func testImageOverflowingBothAxesShrinksByTheTighterAxis() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: 2000, height: 1000), screen: screen)
        XCTAssertEqual(size, CGSize(width: 800, height: 400))
    }

    func testRetinaScreenshotKeepsAspectRatioWithinFraction() {
        let size = ImagePreviewLayout.fittedSize(
            image: CGSize(width: 1440, height: 900),
            screen: CGSize(width: 1512, height: 982)
        )
        XCTAssertEqual(size.width, 1209.6, accuracy: 0.001)
        XCTAssertEqual(size.height, 756, accuracy: 0.001)
        XCTAssertEqual(size.width / size.height, 1440.0 / 900.0, accuracy: 0.001)
    }

    func testZeroImageSizeGivesZero() {
        XCTAssertEqual(ImagePreviewLayout.fittedSize(image: .zero, screen: screen), .zero)
    }

    func testZeroScreenSizeGivesZero() {
        XCTAssertEqual(ImagePreviewLayout.fittedSize(image: CGSize(width: 400, height: 300), screen: .zero), .zero)
    }

    func testNegativeImageSizeGivesZero() {
        let size = ImagePreviewLayout.fittedSize(image: CGSize(width: -10, height: 300), screen: screen)
        XCTAssertEqual(size, .zero)
    }

    func testNegativeScreenSizeGivesZero() {
        let size = ImagePreviewLayout.fittedSize(
            image: CGSize(width: 400, height: 300),
            screen: CGSize(width: 1000, height: -1000)
        )
        XCTAssertEqual(size, .zero)
    }
}
