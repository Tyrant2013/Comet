import XCTest
import CoreGraphics
@testable import PhotoEditor

final class CMCropStateTests: XCTestCase {
    func testCropRectRespondsToZoomAndPan() {
        var state = CMCropState(imageSize: CGSize(width: 200, height: 200), outputAspectRatio: 1)
        let base = state.cropRect(in: CGRect(x: 0, y: 0, width: 200, height: 200))

        state.updateZoomScale(2)
        state.updatePanOffset(CGPoint(x: 0.2, y: -0.2))
        let adjusted = state.cropRect(in: CGRect(x: 0, y: 0, width: 200, height: 200))

        XCTAssertLessThan(adjusted.width, base.width)
        XCTAssertNotEqual(adjusted.midX, base.midX)
        XCTAssertNotEqual(adjusted.midY, base.midY)
    }

    func testRotationAndReset() {
        var state = CMCropState(imageSize: CGSize(width: 100, height: 80), outputAspectRatio: 4.0 / 3.0)
        state.rotate(by: 90)
        XCTAssertEqual(state.rotationDegrees, 90)

        state.updateZoomScale(3)
        state.updatePanOffset(CGPoint(x: 0.3, y: 0.1))
        state.reset()

        XCTAssertEqual(state.rotationDegrees, 0)
        XCTAssertEqual(state.zoomScale, 1)
        XCTAssertEqual(state.panOffset, .zero)
    }

    func testCropOperationKeepsNonZeroExtentAfterRotation() throws {
        let image = TestImageSupport.checkerboard(size: CGSize(width: 160, height: 120))
        var context = CMPhotoEditContext(image: image)
        var state = CMCropState(imageSize: image.extent.size, outputAspectRatio: 1)
        state.rotate(by: 45)
        state.updateZoomScale(1.4)

        try CMCropOperation(state: state).apply(to: &context)
        XCTAssertGreaterThan(context.image.extent.width, 0)
        XCTAssertGreaterThan(context.image.extent.height, 0)
    }
}
