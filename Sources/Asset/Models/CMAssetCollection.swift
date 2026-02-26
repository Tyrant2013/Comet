import Foundation
import Photos

/// 相册模型
public struct CMAssetCollection: Identifiable, Equatable {
    /// 唯一标识符
    public let id: String
    /// PHAssetCollection对象
    let phAssetCollection: PHAssetCollection
    /// 相册名称
    public let title: String
    /// 相册类型
    public let type: PHAssetCollectionType
    /// 相册子类型
    public let subtype: PHAssetCollectionSubtype
    /// 相册中图片数量
    public let assetCount: Int
    
    /// 初始化方法
    /// - Parameters:
    ///   - phAssetCollection: PHAssetCollection对象
    ///   - assetCount: 相册中图片数量
    init(phAssetCollection: PHAssetCollection, assetCount: Int) {
        self.id = phAssetCollection.localIdentifier
        self.phAssetCollection = phAssetCollection
        self.title = phAssetCollection.localizedTitle ?? ""
        self.type = phAssetCollection.assetCollectionType
        self.subtype = phAssetCollection.assetCollectionSubtype
        self.assetCount = assetCount
    }
    
    /// 比较两个CMAssetCollection是否相等
    /// - Parameters:
    ///   - lhs: 左侧CMAssetCollection
    ///   - rhs: 右侧CMAssetCollection
    /// - Returns: 是否相等
    public static func == (lhs: CMAssetCollection, rhs: CMAssetCollection) -> Bool {
        return lhs.id == rhs.id
    }
}