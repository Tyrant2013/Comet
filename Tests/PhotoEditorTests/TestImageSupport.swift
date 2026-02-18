import XCTest
import CoreImage
import CoreGraphics
@testable import PhotoEditor

enum TestImageSupport {
    static let context = CIContext(options: nil)

    static func checkerboard(size: CGSize = CGSize(width: 120, height: 120)) -> CIImage {
        let filter = CIFilter(name: "CICheckerboardGenerator")!
        filter.setValue(CIVector(x: 0, y: 0), forKey: "inputCenter")
        filter.setValue(12.0, forKey: "inputWidth")
        filter.setValue(1.0, forKey: "inputSharpness")
        let image = filter.outputImage!
        return image.cropped(to: CGRect(origin: .zero, size: size))
    }

    static func solid(color: CIColor, size: CGSize = CGSize(width: 80, height: 80)) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(origin: .zero, size: size))
    }

    static func meanAbsoluteDifference(_ lhs: CIImage, _ rhs: CIImage) -> Double {
        let left = rgbaBytes(lhs)
        let right = rgbaBytes(rhs)
        guard left.count == right.count, !left.isEmpty else { return 0 }

        var total: Double = 0
        for i in 0..<left.count {
            total += abs(Double(left[i]) - Double(right[i]))
        }
        return total / Double(left.count)
    }

    static func rgbaBytes(_ image: CIImage) -> [UInt8] {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else { return [] }

        let width = Int(extent.width)
        let height = Int(extent.height)
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)

        context.render(
            image,
            toBitmap: &bytes,
            rowBytes: bytesPerRow,
            bounds: extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return bytes
    }
}
