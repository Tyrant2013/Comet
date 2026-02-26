import Foundation
import Photos

/// 图片资源模型
public struct CMAsset: Identifiable, Equatable, Hashable {
    /// 唯一标识符
    public let id: String
    /// PHAsset对象
    let phAsset: PHAsset
    /// 图片创建日期
    public let creationDate: Date?
    /// 图片宽度
    public let width: CGFloat
    /// 图片高度
    public let height: CGFloat
    
    /// 初始化方法
    /// - Parameter phAsset: PHAsset对象
    init(phAsset: PHAsset) {
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
        self.creationDate = phAsset.creationDate
        self.width = CGFloat(phAsset.pixelWidth)
        self.height = CGFloat(phAsset.pixelHeight)
    }
    
    /// 比较两个CMAsset是否相等
    /// - Parameters:
    ///   - lhs: 左侧CMAsset
    ///   - rhs: 右侧CMAsset
    /// - Returns: 是否相等
    public static func == (lhs: CMAsset, rhs: CMAsset) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Hash值
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}