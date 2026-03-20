import Foundation
import Photos
import UIKit

/// 图片加载器
class CMAssetLoader {
    /// 共享实例
    static let shared = CMAssetLoader()
    
    /// 图片管理器
    private let imageManager = PHCachingImageManager()
    /// 图片缓存
    private let imageCache = NSCache<NSString, UIImage>()
    /// 私有初始化方法
    private init() {
        // 设置缓存大小
        imageCache.countLimit = 200
        imageCache.totalCostLimit = 1024 * 1024 * 150 // 150MB
        
        // 监听内存警告
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    /// 加载图片
    /// - Parameters:
    ///   - asset: 图片资源
    ///   - targetSize: 目标尺寸
    ///   - contentMode: 内容模式
    ///   - completion: 完成回调
    func loadImage(
        for asset: CMAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?, Error?) -> Void
    ) {
        // 检查缓存
        let cacheKey = makeCacheKey(for: asset, targetSize: targetSize)
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage, nil)
            }
            return
        }
        
        // 配置图片请求选项
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset.phAsset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { [weak self] image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            if isCancelled { return }
            
            if let error = info?[PHImageErrorKey] as? Error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // Opportunistic 模式下，先回调降级图再回调高清图。忽略降级图可避免闪烁。
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if isDegraded { return }
            
            guard let image else {
                DispatchQueue.main.async {
                    completion(nil, CMAssetError.assetNotFound)
                }
                return
            }
            
            self?.imageCache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async {
                completion(image, nil)
            }
        }
    }

    /// 读取缓存中的图片（如果存在）
    func cachedImage(for asset: CMAsset, targetSize: CGSize) -> UIImage? {
        imageCache.object(forKey: makeCacheKey(for: asset, targetSize: targetSize))
    }
    
    /// 异步加载图片
    /// - Parameters:
    ///   - asset: 图片资源
    ///   - targetSize: 目标尺寸
    ///   - contentMode: 内容模式
    /// - Returns: 加载的图片
    func loadImageAsync(
        for asset: CMAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            loadImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode
            ) { image, error in
                if let image = image {
                    continuation.resume(returning: image)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: CMAssetError.assetNotFound)
                }
            }
        }
    }
    
    /// 批量加载图片
    /// - Parameters:
    ///   - assets: 图片资源列表
    ///   - targetSize: 目标尺寸
    /// - Returns: 加载的图片字典
    func loadImagesAsync(
        for assets: [CMAsset],
        targetSize: CGSize
    ) async throws -> [CMAsset: UIImage] {
        var result: [CMAsset: UIImage] = [:]
        
        try await withThrowingTaskGroup(of: (CMAsset, UIImage).self) { group in
            for asset in assets {
                group.addTask { [weak self] in
                    guard let self = self else { throw CMAssetError.unknown }
                    let image = try await self.loadImageAsync(for: asset, targetSize: targetSize)
                    return (asset, image)
                }
            }
            
            for try await (asset, image) in group {
                result[asset] = image
            }
        }
        
        return result
    }
    
    /// 加载原图
    /// - Parameter asset: 图片资源
    /// - Returns: 原图
    func loadOriginalImage(for asset: CMAsset) async throws -> UIImage {
        let targetSize = CGSize(width: asset.width, height: asset.height)
        return try await loadImageAsync(for: asset, targetSize: targetSize)
    }
    
    /// 清除缓存
    func clearCache() {
        imageCache.removeAllObjects()
    }
    
    /// 移除指定图片的缓存
    /// - Parameter asset: 图片资源
    func removeFromCache(_ asset: CMAsset) {
        // NSCache没有allKeys属性，无法直接遍历所有缓存项
        // 这里我们只能清除整个缓存或者不实现此功能
        // 如果需要精确控制，建议使用自定义缓存实现
        clearCache()
    }

    private func makeCacheKey(for asset: CMAsset, targetSize: CGSize) -> NSString {
        "\(asset.id)_\(Int(targetSize.width))_\(Int(targetSize.height))" as NSString
    }
}
