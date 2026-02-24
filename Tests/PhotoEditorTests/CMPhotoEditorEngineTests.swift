import XCTest
import CoreImage
@testable import PhotoEditor

final class CMPhotoEditorEngineTests: XCTestCase {
    func testPipelineSupportsPluggableOperations() throws {
        var context = CMPhotoEditContext(image: TestImageSupport.checkerboard())
        let operations: [CMPhotoEditOperation] = [
            CMColorAdjustOperation(configuration: .init(brightness: 0.2, contrast: 1.1, saturation: 1.1, exposureEV: 0)),
            CMFilterOperation(filter: .mono)
        ]

        let output = try CMPhotoEditorEngine().run(operations: operations, context: &context)
        XCTAssertGreaterThan(TestImageSupport.meanAbsoluteDifference(context.originalImage, output), 0.1)
    }

    func testPluginRegistryCanBuildOperation() throws {
        let registry = CMPhotoEditorPluginRegistry()
        registry.register("filter") { config in
            guard let filter = config as? CMPhotoEditorFilter else { return nil }
            return CMFilterOperation(filter: filter)
        }

        let operation = registry.makeOperation(id: "filter", configuration: CMPhotoEditorFilter.noir)
        XCTAssertNotNil(operation)
    }

    func testResetOperationRestoresOriginalImage() throws {
        var context = CMPhotoEditContext(image: TestImageSupport.checkerboard())
        let operations: [CMPhotoEditOperation] = [
            CMColorAdjustOperation(configuration: .init(brightness: 0.3, contrast: 1.2, saturation: 1.3, exposureEV: 0.2)),
            CMResetOperation()
        ]

        _ = try CMPhotoEditorEngine().run(operations: operations, context: &context)
        XCTAssertEqual(TestImageSupport.meanAbsoluteDifference(context.originalImage, context.image), 0)
    }
}
