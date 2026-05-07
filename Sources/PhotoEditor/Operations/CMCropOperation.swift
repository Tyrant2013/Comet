import Foundation
import CoreImage
import CoreGraphics
import UIKit

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
    
    public static func == (lhs: CMCropOperation, rhs: CMCropOperation) -> Bool {
        return lhs.id == rhs.id && lhs.state == rhs.state
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(state)
    }
}

extension CMCropOperation {
    func cropImage(_ image: UIImage, to rect: CGRect, withRotation rotation: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)
        
        if rotation != 0 {
            return croppedImage.rotated(by: rotation)
        }
        
        return croppedImage
    }
}

extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * (.pi / 180)
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: size))
        imageView.image = self
        imageView.transform = CGAffineTransform(rotationAngle: radians)
        let rotatedSize = imageView.frame.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return rotatedImage
        }
        return nil
    }
}
