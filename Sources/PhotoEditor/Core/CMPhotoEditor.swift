import Foundation
import CoreImage

public enum CMPhotoEditor {
    public static func edit(_ image: CIImage,
                            operations: [CMPhotoEditOperation],
                            metadata: [String: Any] = [:]) throws -> CIImage {
        var context = CMPhotoEditContext(image: image, metadata: metadata)
        return try CMPhotoEditorEngine().run(operations: operations, context: &context)
    }
}
