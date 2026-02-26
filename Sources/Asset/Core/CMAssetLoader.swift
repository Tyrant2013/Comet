import Foundation
import Photos
import UIKit

/// 图片加载器
class CMAssetLoader {
    /// 共享实例
    static let shared = CMAssetLoader()
    
    /// 图片管理器
    private let imageManager = PHImageManager.default()
    /// 图片缓存
    private let imageCache = NSCache<NSString, UIImage>()
    /// 并发队列
    private let queue = DispatchQueue(label: "com.comet.asset.loader", qos: .userInitiated, attributes: .concurrent)
    
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
        let cacheKey = "\(asset.id)_\(targetSize.width)_\(targetSize.height)" as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            completion(cachedImage, nil)
            return
        }
        
        // 配置图片请求选项
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        // 在并发队列中请求图片
        queue.async {
            self.imageManager.requestImage(
                for: asset.phAsset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { [weak self] image, info in
                DispatchQueue.main.async {
                    if let image = image {
                        // 缓存图片
                        self?.imageCache.setObject(image, forKey: cacheKey)
                        completion(image, nil)
                    } else if let error = info?[PHImageErrorKey] as? Error {
                        completion(nil, error)
                    } else {
                        completion(nil, CMAssetError.assetNotFound)
                    }
                }
            }
        }
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
}