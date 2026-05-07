import Foundation
import CoreImage

public final class CMPhotoEditorEngine {
    private struct OperationKey: Hashable {
        let id: String
        let hash: Int
    }
    
    private var operationCache: [OperationKey: CIImage] = [:]
    
    public init() {}

    @discardableResult
    public func run(operations: [any CMPhotoEditOperation], context: inout CMPhotoEditContext) throws -> CIImage {
        var currentImage = context.image
        
        for operation in operations {
            let key = OperationKey(id: operation.id, hash: operation.hashValue)
            
            if let cachedImage = operationCache[key] {
                currentImage = cachedImage
            } else {
                try operation.apply(to: &context)
                let processedImage = context.image
                operationCache[key] = processedImage
                currentImage = processedImage
            }
        }
        
        return currentImage
    }
    
    public func clearCache() {
        operationCache.removeAll()
    }
}
