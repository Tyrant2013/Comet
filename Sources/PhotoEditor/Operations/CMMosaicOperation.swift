import Foundation
import CoreImage
import CoreGraphics

public enum CMMosaicOperationError: Error {
    case detectorMissing
}

public struct CMMosaicOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable {
        public var manualRegions: [CGRect]
        public var autoDetectSensitiveData: Bool
        public var mosaicScale: Double

        public init(manualRegions: [CGRect] = [],
                    autoDetectSensitiveData: Bool = false,
                    mosaicScale: Double = 24) {
            self.manualRegions = manualRegions
            self.autoDetectSensitiveData = autoDetectSensitiveData
            self.mosaicScale = max(1, mosaicScale)
        }
    }

    public let id = "mosaic"
    public let configuration: Configuration
    private let detector: CMSensitiveDataDetecting?

    public init(configuration: Configuration, detector: CMSensitiveDataDetecting? = nil) {
        self.configuration = configuration
        self.detector = detector
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        var regions = configuration.manualRegions

        if configuration.autoDetectSensitiveData {
            guard let detector else { throw CMMosaicOperationError.detectorMissing }
            let matches = try detector.detectSensitiveData(in: context.image)
            regions.append(contentsOf: matches.map(\.bounds))
        }

        let normalizedRegions = sanitizeRegions(regions, in: context.image.extent)
        guard !normalizedRegions.isEmpty else { return }

        guard let mosaicFilter = CIFilter(name: "CIPixellate") else { return }
        mosaicFilter.setValue(context.image, forKey: kCIInputImageKey)
        mosaicFilter.setValue(configuration.mosaicScale, forKey: kCIInputScaleKey)
        guard let mosaicImage = mosaicFilter.outputImage else { return }

        let maskImage = makeMaskImage(regions: normalizedRegions, extent: context.image.extent)
        let blend = CIFilter(name: "CIBlendWithMask")
        blend?.setValue(mosaicImage, forKey: kCIInputImageKey)
        blend?.setValue(context.image, forKey: kCIInputBackgroundImageKey)
        blend?.setValue(maskImage, forKey: kCIInputMaskImageKey)

        if let output = blend?.outputImage {
            context.image = output.cropped(to: context.image.extent)
        }
    }

    private func sanitizeRegions(_ regions: [CGRect], in extent: CGRect) -> [CGRect] {
        regions.map { $0.standardized.intersection(extent) }.filter { !$0.isNull && !$0.isEmpty }
    }

    private func makeMaskImage(regions: [CGRect], extent: CGRect) -> CIImage {
        let transparent = CIImage(color: .clear).cropped(to: extent)

        return regions.reduce(transparent) { partial, rect in
            let generator = CIFilter(name: "CIConstantColorGenerator")
            generator?.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: kCIInputColorKey)
            let whiteRect = (generator?.outputImage ?? CIImage(color: .white)).cropped(to: rect)

            let composite = CIFilter(name: "CISourceOverCompositing")
            composite?.setValue(whiteRect, forKey: kCIInputImageKey)
            composite?.setValue(partial, forKey: kCIInputBackgroundImageKey)
            return (composite?.outputImage ?? partial).cropped(to: extent)
        }
    }
}
