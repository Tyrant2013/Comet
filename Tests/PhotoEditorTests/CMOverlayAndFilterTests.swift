import XCTest
import CoreImage
import CoreGraphics
@testable import PhotoEditor

final class CMOverlayAndFilterTests: XCTestCase {
    func testColorAdjustChangesImage() throws {
        let image = TestImageSupport.checkerboard()
        var context = CMPhotoEditContext(image: image)
        try CMColorAdjustOperation(configuration: .init(brightness: 0.25, contrast: 1.2, saturation: 0.8, exposureEV: 0.1)).apply(to: &context)

        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testFilterChangesImage() throws {
        let image = TestImageSupport.checkerboard()
        var context = CMPhotoEditContext(image: image)
        try CMFilterOperation(filter: .chrome).apply(to: &context)

        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testTextOverlayChangesImage() throws {
        let image = TestImageSupport.solid(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1), size: CGSize(width: 160, height: 100))
        var context = CMPhotoEditContext(image: image)

        let operation = CMTextOverlayOperation(configuration: .init(
            text: "CONFIDENTIAL",
            normalizedOrigin: CGPoint(x: 0.1, y: 0.45),
            fontSize: 26,
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ))

        try operation.apply(to: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testWatermarkOverlayChangesImage() throws {
        let image = TestImageSupport.solid(color: CIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), size: CGSize(width: 180, height: 120))
        var context = CMPhotoEditContext(image: image)

        let operation = CMWatermarkOverlayOperation(configuration: .init(
            text: "Comet",
            normalizedOrigin: CGPoint(x: 0.1, y: 0.1),
            fontSize: 24,
            color: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            opacity: 0.6,
            rotationDegrees: -15
        ))

        try operation.apply(to: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testWatermarkRemovalChangesTargetRegion() throws {
        let image = TestImageSupport.checkerboard(size: CGSize(width: 160, height: 120))
        var context = CMPhotoEditContext(image: image)

        let operation = CMWatermarkRemovalOperation(configuration: .init(
            regions: [CGRect(x: 110, y: 10, width: 40, height: 18)],
            blurRadius: 12,
            featherRadius: 3
        ))

        try operation.apply(to: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.01)
    }

    func testBackgroundRemovalUsesProvidedMask() throws {
        let image = TestImageSupport.solid(color: CIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1), size: CGSize(width: 100, height: 100))
        var context = CMPhotoEditContext(image: image)

        let operation = CMBackgroundRemovalOperation(configuration: .init(edgeFeatherRadius: 0)) { input in
            let extent = input.extent
            let leftHalf = CIImage(color: .white).cropped(to: CGRect(
                x: extent.minX,
                y: extent.minY,
                width: extent.width * 0.5,
                height: extent.height
            ))
            let rightHalf = CIImage(color: .black).cropped(to: CGRect(
                x: extent.minX + extent.width * 0.5,
                y: extent.minY,
                width: extent.width * 0.5,
                height: extent.height
            ))
            let composite = CIFilter(name: "CISourceOverCompositing")
            composite?.setValue(leftHalf, forKey: kCIInputImageKey)
            composite?.setValue(rightHalf, forKey: kCIInputBackgroundImageKey)
            return (composite?.outputImage ?? leftHalf).cropped(to: extent)
        }

        try operation.apply(to: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }
}
