import XCTest
import CoreImage
@testable import PhotoEditor

final class CMMosaicOperationTests: XCTestCase {
    func testManualMosaicChangesImage() throws {
        let image = TestImageSupport.checkerboard(size: CGSize(width: 200, height: 160))
        var context = CMPhotoEditContext(image: image)

        let op = CMMosaicOperation(configuration: .init(
            manualRegions: [CGRect(x: 40, y: 40, width: 80, height: 50)],
            autoDetectSensitiveData: false,
            mosaicScale: 18
        ))

        try op.apply(to: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testAutoMosaicUsesDetectorMatches() throws {
        let image = TestImageSupport.checkerboard(size: CGSize(width: 200, height: 120))
        var context = CMPhotoEditContext(image: image)

        let detector = MockSensitiveDataDetector(matches: [
            CMSensitiveDataMatch(bounds: CGRect(x: 20, y: 20, width: 100, height: 40), text: "1234-56-7890")
        ])

        let op = CMMosaicOperation(configuration: .init(autoDetectSensitiveData: true, mosaicScale: 22), detector: detector)
        try op.apply(to: &context)

        XCTAssertEqual(detector.detectCallCount, 1)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(image, context.image), 0.1)
    }

    func testAutoMosaicWithoutDetectorThrows() throws {
        let image = TestImageSupport.checkerboard(size: CGSize(width: 80, height: 80))
        var context = CMPhotoEditContext(image: image)

        let op = CMMosaicOperation(configuration: .init(autoDetectSensitiveData: true))
        XCTAssertThrowsError(try op.apply(to: &context))
    }
}

private final class MockSensitiveDataDetector: CMSensitiveDataDetecting {
    private let matches: [CMSensitiveDataMatch]
    private(set) var detectCallCount = 0

    init(matches: [CMSensitiveDataMatch]) {
        self.matches = matches
    }

    func detectSensitiveData(in image: CIImage) throws -> [CMSensitiveDataMatch] {
        detectCallCount += 1
        return matches
    }
}
