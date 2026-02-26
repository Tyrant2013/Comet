import Foundation
import Photos

/// 相册管理类
class CMAssetManager {
    /// 共享实例
    static let shared = CMAssetManager()
    
    /// 私有初始化方法
    private init() {}
    
    /// 请求相册访问权限
    /// - Returns: 是否获得权限
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// 获取相册权限状态
    /// - Returns: 权限状态
    func getPermissionStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
    
    /// 获取所有相册列表
    /// - Returns: 相册列表
    func getAlbums() async throws -> [CMAssetCollection] {
        guard getPermissionStatus() == .authorized else {
            throw CMAssetError.permissionDenied
        }
        
        return await withCheckedContinuation { continuation in
            var albums: [CMAssetCollection] = []
            
            let fetchOptions = PHFetchOptions()
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
            
            smartAlbums.enumerateObjects { collection, _, _ in
                let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
                if assetCount > 0 {
                    albums.append(CMAssetCollection(phAssetCollection: collection, assetCount: assetCount))
                }
            }
            
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            userAlbums.enumerateObjects { collection, _, _ in
                let assetCount = PHAsset.fetchAssets(in: collection, options: nil).count
                albums.append(CMAssetCollection(phAssetCollection: collection, assetCount: assetCount))
            }
            
            continuation.resume(returning: albums)
        }
    }
    
    /// 创建新相册
    /// - Parameter title: 相册名称
    /// - Returns: 创建的相册
    func createAlbum(title: String) async throws -> CMAssetCollection {
        guard getPermissionStatus() == .authorized else {
            throw CMAssetError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var createdCollection: PHObjectPlaceholder?
            var error: Error?
            
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                createdCollection = creationRequest.placeholderForCreatedAssetCollection
            } completionHandler: { success, err in
                if success, let collection = createdCollection {
                    let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collection.localIdentifier], options: nil)
                    if let assetCollection = fetchResult.firstObject {
                        continuation.resume(returning: CMAssetCollection(phAssetCollection: assetCollection, assetCount: 0))
                    } else {
                        continuation.resume(throwing: CMAssetError.albumNotFound)
                    }
                } else {
                    continuation.resume(throwing: error ?? CMAssetError.operationFailed("创建相册失败"))
                }
            }
        }
    }
    
    /// 删除相册
    /// - Parameter album: 要删除的相册
    /// - Returns: 是否删除成功
    func deleteAlbum(_ album: CMAssetCollection) async throws -> Bool {
        guard getPermissionStatus() == .authorized else {
            throw CMAssetError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections([album.phAssetCollection] as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: error ?? CMAssetError.operationFailed("删除相册失败"))
                }
            }
        }
    }
    
    /// 获取指定相册下的图片
    /// - Parameter album: 相册
    /// - Returns: 图片列表
    func getAssets(in album: CMAssetCollection) async throws -> [CMAsset] {
        guard getPermissionStatus() == .authorized else {
            throw CMAssetError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(in: album.phAssetCollection, options: fetchOptions)
            var assets: [CMAsset] = []
            
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(CMAsset(phAsset: asset))
            }
            
            continuation.resume(returning: assets)
        }
    }
    
    /// 使用Cursor机制获取图片（支持大量图片）
    /// - Parameters:
    ///   - album: 相册
    ///   - batchSize: 批量大小
    /// - Returns: 图片游标
    func getAssetCursor(in album: CMAssetCollection, batchSize: Int = 50) -> CMAssetCursor {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(in: album.phAssetCollection, options: fetchOptions)
        return CMAssetCursor(fetchResult: fetchResult, batchSize: batchSize)
    }
}

/// 图片游标，用于高效获取大量图片
class CMAssetCursor {
    private let fetchResult: PHFetchResult<PHAsset>
    private let batchSize: Int
    private var currentIndex = 0
    
    /// 初始化方法
    /// - Parameters:
    ///   - fetchResult: PHFetchResult对象
    ///   - batchSize: 批量大小
    init(fetchResult: PHFetchResult<PHAsset>, batchSize: Int) {
        self.fetchResult = fetchResult
        self.batchSize = batchSize
    }
    
    /// 是否还有更多图片
    var hasMore: Bool {
        return currentIndex < fetchResult.count
    }
    
    /// 获取下一批图片
    /// - Returns: 图片列表
    func nextBatch() -> [CMAsset] {
        let endIndex = min(currentIndex + batchSize, fetchResult.count)
        var assets: [CMAsset] = []
        
        for i in currentIndex..<endIndex {
            let phAsset = fetchResult.object(at: i)
            assets.append(CMAsset(phAsset: phAsset))
        }
        
        currentIndex = endIndex
        return assets
    }
    
    /// 重置游标
    func reset() {
        currentIndex = 0
    }
    
    /// 总图片数量
    var totalCount: Int {
        return fetchResult.count
    }
}
