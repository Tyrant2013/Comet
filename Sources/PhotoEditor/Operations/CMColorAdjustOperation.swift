import Foundation
import CoreImage

public struct CMColorAdjustOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable, Hashable {
        public var brightness: Double
        public var contrast: Double
        public var saturation: Double
        public var exposureEV: Double
        public var warmth: Double
        public var tint: Double

        public init(brightness: Double = 0,
                    contrast: Double = 1,
                    saturation: Double = 1,
                    exposureEV: Double = 0,
                    warmth: Double = 0,
                    tint: Double = 0) {
            self.brightness = brightness
            self.contrast = contrast
            self.saturation = saturation
            self.exposureEV = exposureEV
            self.warmth = warmth
            self.tint = tint
        }
    }

    public let id = "color_adjust"
    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(context.image, forKey: kCIInputImageKey)
        controls?.setValue(configuration.brightness, forKey: kCIInputBrightnessKey)
        controls?.setValue(configuration.contrast, forKey: kCIInputContrastKey)
        controls?.setValue(configuration.saturation, forKey: kCIInputSaturationKey)

        guard var colorAdjusted = controls?.outputImage else { return }

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(colorAdjusted, forKey: kCIInputImageKey)
        exposure?.setValue(configuration.exposureEV, forKey: kCIInputEVKey)
        colorAdjusted = (exposure?.outputImage ?? colorAdjusted).cropped(to: context.image.extent)

        // 应用 warmth 和 tint
        if configuration.warmth != 0 || configuration.tint != 0 {
            let colorMatrix = CIFilter(name: "CIColorMatrix")!
            let warmth = configuration.warmth
            let tint = configuration.tint
            
            let matrix = CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
            let vector = CIVector(x: warmth * 0.1, y: 0.0, z: tint * -0.1, w: 0.0)
            
            colorMatrix.setValue(colorAdjusted, forKey: kCIInputImageKey)
            colorMatrix.setValue(matrix, forKey: "inputRVector")
            colorMatrix.setValue(matrix, forKey: "inputGVector")
            colorMatrix.setValue(matrix, forKey: "inputBVector")
            colorMatrix.setValue(vector, forKey: "inputBiasVector")
            
            colorAdjusted = colorMatrix.outputImage!.cropped(to: context.image.extent)
        }

        context.image = colorAdjusted
    }
    
    public static func == (lhs: CMColorAdjustOperation, rhs: CMColorAdjustOperation) -> Bool {
        return lhs.id == rhs.id && lhs.configuration == rhs.configuration
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(configuration)
    }
}
