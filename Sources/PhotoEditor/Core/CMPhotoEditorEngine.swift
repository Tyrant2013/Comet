import Foundation
import CoreImage

public final class CMPhotoEditorEngine {
    // 缓存机制：使用字典缓存操作组合的结果
    private var operationCache: [String: CIImage] = [:]
    
    public init() {}

    @discardableResult
    public func run(operations: [CMPhotoEditOperation], context: inout CMPhotoEditContext) throws -> CIImage {
        // 生成缓存键
        let cacheKey = generateCacheKey(operations: operations, imageHash: context.originalImage.hash)
        
        // 检查缓存
        if let cachedImage = operationCache[cacheKey] {
            context.image = cachedImage
            return cachedImage
        }
        
        // 重置图像到原始状态
        context.resetImage()
        
        // 应用所有操作
        for operation in operations {
            try operation.apply(to: &context)
        }
        
        // 缓存结果
        operationCache[cacheKey] = context.image
        
        return context.image
    }
    
    // 异步处理方法，避免阻塞UI
    public func runAsync(operations: [CMPhotoEditOperation], context: CMPhotoEditContext, completion: @escaping (Result<CIImage, Error>) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                var mutableContext = context
                let result = try self.run(operations: operations, context: &mutableContext)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 清理缓存
    public func clearCache() {
        operationCache.removeAll()
    }
    
    // 生成缓存键
    private func generateCacheKey(operations: [CMPhotoEditOperation], imageHash: Int) -> String {
        var key = "imageHash)"
        for operation in operations {
            key += "_" + operation.id
            
            // 对于颜色调整操作，添加配置参数到缓存键
            if let colorAdjustOp = operation as? CMColorAdjustOperation {
                key += "_b" + String(format: "%.2f", colorAdjustOp.configuration.brightness)
                key += "_c" + String(format: "%.2f", colorAdjustOp.configuration.contrast)
                key += "_s" + String(format: "%.2f", colorAdjustOp.configuration.saturation)
                key += "_e" + String(format: "%.2f", colorAdjustOp.configuration.exposureEV)
            }
            // 可以为其他类型的操作添加相应的配置参数
        }
        return key
    }
}
