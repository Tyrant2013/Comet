import Foundation
import CoreImage

public struct CMColorAdjustOperation: CMPhotoEditOperation {
    public struct Configuration: Sendable {
        public var brightness: Double
        public var contrast: Double
        public var saturation: Double
        public var exposureEV: Double

        public init(brightness: Double = 0,
                    contrast: Double = 1,
                    saturation: Double = 1,
                    exposureEV: Double = 0) {
            self.brightness = brightness
            self.contrast = contrast
            self.saturation = saturation
            self.exposureEV = exposureEV
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

        guard let colorAdjusted = controls?.outputImage else { return }

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(colorAdjusted, forKey: kCIInputImageKey)
        exposure?.setValue(configuration.exposureEV, forKey: kCIInputEVKey)
        context.image = (exposure?.outputImage ?? colorAdjusted).cropped(to: context.image.extent)
    }
}
