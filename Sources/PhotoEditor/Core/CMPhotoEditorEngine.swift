import Foundation
import CoreImage

public final class CMPhotoEditorEngine {
    public init() {}

    @discardableResult
    public func run(operations: [CMPhotoEditOperation], context: inout CMPhotoEditContext) throws -> CIImage {
        for operation in operations {
            try operation.apply(to: &context)
        }
        return context.image
    }
}
