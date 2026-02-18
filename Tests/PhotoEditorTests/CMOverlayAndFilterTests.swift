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
}
