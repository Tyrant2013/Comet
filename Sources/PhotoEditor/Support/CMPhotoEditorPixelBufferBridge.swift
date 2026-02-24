import Foundation
import CoreImage
import AVFoundation

public enum CMPhotoEditorPixelBufferBridge {
    public static func makeCIImage(from pixelBuffer: CVPixelBuffer) -> CIImage {
        CIImage(cvPixelBuffer: pixelBuffer)
    }

    public static func makePixelBuffer(from image: CIImage,
                                       context: CIContext = CIContext()) -> CVPixelBuffer? {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(extent.width),
            Int(extent.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }
        context.render(image, to: pixelBuffer)
        return pixelBuffer
    }
}
