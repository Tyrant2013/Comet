import Foundation
import CoreImage
import CoreGraphics
import CoreText

public struct CMTextOverlayOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable, Hashable {
        public var text: String
        public var normalizedOrigin: CGPoint
        public var fontSize: CGFloat
        public var color: CGColor

        public init(text: String,
                    normalizedOrigin: CGPoint,
                    fontSize: CGFloat = 32,
                    color: CGColor = CGColor(gray: 1, alpha: 1)) {
            self.text = text
            self.normalizedOrigin = normalizedOrigin
            self.fontSize = fontSize
            self.color = color
        }
    }

    public let id = "text_overlay"
    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        guard !configuration.text.isEmpty else { return }
        let extent = context.image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return }

        guard let textImage = makeTextImage(targetSize: extent.size) else { return }

        let x = extent.minX + max(0, min(1, configuration.normalizedOrigin.x)) * extent.width
        let y = extent.minY + max(0, min(1, configuration.normalizedOrigin.y)) * extent.height
        let transformedText = textImage.transformed(by: .init(translationX: x, y: y))

        let compositing = CIFilter(name: "CISourceOverCompositing")
        compositing?.setValue(transformedText, forKey: kCIInputImageKey)
        compositing?.setValue(context.image, forKey: kCIInputBackgroundImageKey)

        if let output = compositing?.outputImage {
            context.image = output.cropped(to: extent)
        }
    }

    private func makeTextImage(targetSize: CGSize) -> CIImage? {
        let text = configuration.text as NSString
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, configuration.fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): configuration.color
        ]

        let attributed = NSAttributedString(string: text as String, attributes: attrs)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let maxSize = CGSize(width: targetSize.width, height: targetSize.height)
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, maxSize, nil)
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
    
    public static func == (lhs: CMTextOverlayOperation, rhs: CMTextOverlayOperation) -> Bool {
        return lhs.id == rhs.id && lhs.configuration == rhs.configuration
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(configuration)
    }
}
