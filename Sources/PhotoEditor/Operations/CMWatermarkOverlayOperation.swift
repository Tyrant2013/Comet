import Foundation
import CoreImage
import CoreGraphics
import CoreText

public struct CMWatermarkOverlayOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable, Hashable {
        public var text: String
        public var normalizedOrigin: CGPoint
        public var fontSize: CGFloat
        public var color: CGColor
        public var opacity: CGFloat
        public var rotationDegrees: Double

        public init(text: String,
                    normalizedOrigin: CGPoint,
                    fontSize: CGFloat = 26,
                    color: CGColor = CGColor(gray: 1, alpha: 1),
                    opacity: CGFloat = 0.35,
                    rotationDegrees: Double = 0) {
            self.text = text
            self.normalizedOrigin = normalizedOrigin
            self.fontSize = fontSize
            self.color = color
            self.opacity = max(0, min(1, opacity))
            self.rotationDegrees = rotationDegrees
        }
    }

    public let id = "watermark_overlay"
    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        guard !configuration.text.isEmpty else { return }

        let extent = context.image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return }

        guard var watermark = makeTextImage() else { return }

        if configuration.rotationDegrees != 0 {
            let radians = CGFloat(configuration.rotationDegrees * .pi / 180)
            let center = CGPoint(x: watermark.extent.midX, y: watermark.extent.midY)
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            watermark = watermark.transformed(by: transform)
        }

        let x = extent.minX + max(0, min(1, configuration.normalizedOrigin.x)) * extent.width
        let y = extent.minY + max(0, min(1, configuration.normalizedOrigin.y)) * extent.height
        let transformed = watermark.transformed(by: .init(translationX: x, y: y))

        let composite = CIFilter(name: "CISourceOverCompositing")
        composite?.setValue(transformed, forKey: kCIInputImageKey)
        composite?.setValue(context.image, forKey: kCIInputBackgroundImageKey)

        if let output = composite?.outputImage {
            context.image = output.cropped(to: extent)
        }
    }

    private func makeTextImage() -> CIImage? {
        let alphaColor = configuration.color.copy(alpha: configuration.opacity) ?? configuration.color
        let text = configuration.text as NSString
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, configuration.fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): alphaColor
        ]

        let attributed = NSAttributedString(string: text as String, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: 2000, height: 2000),
            nil
        )

        let width = max(1, Int(ceil(suggested.width)))
        let height = max(1, Int(ceil(suggested.height)))

        guard let cg = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        cg.clear(CGRect(x: 0, y: 0, width: width, height: height))
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: 1, y: -1)

        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributed.length), path, nil)
        CTFrameDraw(frame, cg)

        guard let cgImage = cg.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
    }
    
    public static func == (lhs: CMWatermarkOverlayOperation, rhs: CMWatermarkOverlayOperation) -> Bool {
        return lhs.id == rhs.id && lhs.configuration == rhs.configuration
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(configuration)
    }
}
