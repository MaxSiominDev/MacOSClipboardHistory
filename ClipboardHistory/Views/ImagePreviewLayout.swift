import CoreGraphics

enum ImagePreviewLayout {
    private static let screenFraction: CGFloat = 0.8

    /// Shrinks `image` to fit `screenFraction` of `screen`, never enlarging it past its natural size.
    static func fittedSize(image: CGSize, screen: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0, screen.width > 0, screen.height > 0 else { return .zero }
        let scale = min(
            1,
            screenFraction * screen.width / image.width,
            screenFraction * screen.height / image.height
        )
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}
