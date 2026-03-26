import UIKit

public extension UIImage {
    func cm_croppedImage(frame: CGRect, angle: Int, circularClip: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = !cm_hasAlpha && !circularClip
        format.scale = scale

        let renderer = UIGraphicsImageRenderer(size: frame.size, format: format)
        let croppedImage = renderer.image { rendererContext in
            let context = rendererContext.cgContext

            if circularClip {
                context.addEllipse(in: CGRect(origin: .zero, size: frame.size))
                context.clip()
            }

            context.translateBy(x: -frame.origin.x, y: -frame.origin.y)

            if angle != 0 {
                let rotation = CGFloat(angle) * (.pi / 180.0)
                let imageBounds = CGRect(origin: .zero, size: size)
                let rotatedBounds = imageBounds.applying(CGAffineTransform(rotationAngle: rotation))
                context.translateBy(x: -rotatedBounds.origin.x, y: -rotatedBounds.origin.y)
                context.rotate(by: rotation)
            }

            draw(at: .zero)
        }

        guard let cgImage = croppedImage.cgImage else { return croppedImage }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private var cm_hasAlpha: Bool {
        guard let cgImage = cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}
