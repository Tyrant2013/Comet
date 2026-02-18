import Foundation
import CoreImage
import CoreGraphics

public struct CMCropOperation: CMPhotoEditOperation {
    public let id = "crop"
    public var state: CMCropState

    public init(state: CMCropState) {
        self.state = state
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        let currentImage = context.image
        let radians = state.rotationDegrees * (.pi / 180)

        var workingImage = currentImage
        if radians != 0 {
            let center = CGPoint(x: currentImage.extent.midX, y: currentImage.extent.midY)
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: center.x, y: center.y)
            transform = transform.rotated(by: radians)
            transform = transform.translatedBy(x: -center.x, y: -center.y)
            workingImage = currentImage.transformed(by: transform)
        }

        let rect = state.cropRect(in: workingImage.extent)
        context.image = workingImage.cropped(to: rect)
    }
}
