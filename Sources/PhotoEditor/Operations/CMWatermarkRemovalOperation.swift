import Foundation
import CoreImage
import CoreGraphics

public struct CMWatermarkRemovalOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable {
        public var regions: [CGRect]
        public var blurRadius: Double
        public var featherRadius: Double

        public init(regions: [CGRect],
                    blurRadius: Double = 18,
                    featherRadius: Double = 4) {
            self.regions = regions
            self.blurRadius = max(0, blurRadius)
            self.featherRadius = max(0, featherRadius)
        }
    }

    public let id = "watermark_removal"
    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        let extent = context.image.extent.integral
        let regions = sanitizeRegions(configuration.regions, in: extent)
        guard !regions.isEmpty else { return }

        let softenedImage: CIImage = {
            if configuration.blurRadius <= 0 { return context.image }
            let blur = CIFilter(name: "CIGaussianBlur")
            blur?.setValue(context.image, forKey: kCIInputImageKey)
            blur?.setValue(configuration.blurRadius, forKey: kCIInputRadiusKey)
            return (blur?.outputImage ?? context.image).cropped(to: extent)
        }()

        let maskImage = makeMaskImage(regions: regions, extent: extent, featherRadius: configuration.featherRadius)

        let blend = CIFilter(name: "CIBlendWithMask")
        blend?.setValue(softenedImage, forKey: kCIInputImageKey)
        blend?.setValue(context.image, forKey: kCIInputBackgroundImageKey)
        blend?.setValue(maskImage, forKey: kCIInputMaskImageKey)

        if let output = blend?.outputImage {
            context.image = output.cropped(to: extent)
        }
    }

    private func sanitizeRegions(_ regions: [CGRect], in extent: CGRect) -> [CGRect] {
        regions.map { $0.standardized.intersection(extent) }.filter { !$0.isNull && !$0.isEmpty }
    }

    private func makeMaskImage(regions: [CGRect], extent: CGRect, featherRadius: Double) -> CIImage {
        let transparent = CIImage(color: .clear).cropped(to: extent)

        let hardMask = regions.reduce(transparent) { partial, rect in
            let generator = CIFilter(name: "CIConstantColorGenerator")
            generator?.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: kCIInputColorKey)
            let whiteRect = (generator?.outputImage ?? CIImage(color: .white)).cropped(to: rect)

            let composite = CIFilter(name: "CISourceOverCompositing")
            composite?.setValue(whiteRect, forKey: kCIInputImageKey)
            composite?.setValue(partial, forKey: kCIInputBackgroundImageKey)
            return (composite?.outputImage ?? partial).cropped(to: extent)
        }

        guard featherRadius > 0 else { return hardMask }

        let blur = CIFilter(name: "CIGaussianBlur")
        blur?.setValue(hardMask, forKey: kCIInputImageKey)
        blur?.setValue(featherRadius, forKey: kCIInputRadiusKey)
        return (blur?.outputImage ?? hardMask).cropped(to: extent)
    }
}
