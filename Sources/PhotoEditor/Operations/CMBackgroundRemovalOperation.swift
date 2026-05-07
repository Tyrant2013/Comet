import Foundation
import CoreImage
import CoreGraphics
#if canImport(Vision)
import Vision
#endif

public enum CMBackgroundRemovalOperationError: Error {
    case maskGenerationUnavailable
}

public struct CMBackgroundRemovalOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable, Hashable {
        public var edgeFeatherRadius: Double

        public init(edgeFeatherRadius: Double = 1.5) {
            self.edgeFeatherRadius = max(0, edgeFeatherRadius)
        }
    }

    public typealias MaskProvider = (CIImage) throws -> CIImage?

    public let id = "background_removal"
    public let configuration: Configuration
    private let maskProvider: MaskProvider

    public init(configuration: Configuration = .init(),
                maskProvider: @escaping MaskProvider = CMBackgroundRemovalOperation.defaultMaskProvider) {
        self.configuration = configuration
        self.maskProvider = maskProvider
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        let extent = context.image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return }

        guard var maskImage = try maskProvider(context.image)?.cropped(to: extent) else { return }

        if configuration.edgeFeatherRadius > 0,
           let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(maskImage, forKey: kCIInputImageKey)
            blur.setValue(configuration.edgeFeatherRadius, forKey: kCIInputRadiusKey)
            maskImage = (blur.outputImage ?? maskImage).cropped(to: extent)
        }

        let transparentBackground = CIImage(color: .clear).cropped(to: extent)
        let blend = CIFilter(name: "CIBlendWithMask")
        blend?.setValue(context.image, forKey: kCIInputImageKey)
        blend?.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
        blend?.setValue(maskImage, forKey: kCIInputMaskImageKey)

        if let output = blend?.outputImage {
            context.image = output.cropped(to: extent)
        }
    }

    public static func defaultMaskProvider(for image: CIImage) throws -> CIImage? {
        #if canImport(Vision)
        if #available(iOS 15.0, macOS 12.0, *) {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.first else { return nil }
            let maskImage = CIImage(cvPixelBuffer: observation.pixelBuffer)
            return resizeMask(maskImage, to: image.extent)
        }
        #endif

        return nil
    }

    private static func resizeMask(_ mask: CIImage, to extent: CGRect) -> CIImage {
        guard mask.extent.width > 0, mask.extent.height > 0 else {
            return mask.cropped(to: extent)
        }

        let scaleX = extent.width / mask.extent.width
        let scaleY = extent.height / mask.extent.height

        let scaled = mask.transformed(by: .init(scaleX: scaleX, y: scaleY))
        let translated = scaled.transformed(by: .init(
            translationX: extent.minX - scaled.extent.minX,
            y: extent.minY - scaled.extent.minY
        ))

        return translated.cropped(to: extent)
    }
    
    public static func == (lhs: CMBackgroundRemovalOperation, rhs: CMBackgroundRemovalOperation) -> Bool {
        return lhs.id == rhs.id && lhs.configuration == rhs.configuration
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(configuration)
    }
}
