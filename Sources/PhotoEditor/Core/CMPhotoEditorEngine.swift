import Foundation
import CoreImage

public final class CMPhotoEditorEngine {
    private var operationCache: [String: CIImage] = [:]
    
    public init() {}

    @discardableResult
    public func run(operations: [CMPhotoEditOperation], context: inout CMPhotoEditContext) throws -> CIImage {
        var currentImage = context.image
        
        for operation in operations {
            let cacheKey = "\(operation.operationType)-\(operation.hashValue)"
            
            if let cachedImage = operationCache[cacheKey] {
                currentImage = cachedImage
            } else {
                let originalImage = currentImage
                try operation.apply(to: &context)
                let processedImage = context.image
                operationCache[cacheKey] = processedImage
                currentImage = processedImage
            }
        }
        
        return currentImage
    }
    
    public func clearCache() {
        operationCache.removeAll()
    }
}

// 为操作添加哈希值计算
extension CMPhotoEditOperation {
    var operationType: String {
        return String(describing: type(of: self))
    }
    
    var hashValue: Int {
        return operationType.hashValue
    }
}
