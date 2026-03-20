import Foundation
import Photos
import UIKit

/// 图片资源模型
public class CMAsset: Identifiable, Equatable, Hashable, ObservableObject {
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
    
    let targetSize = CGSize(width: 200, height: 200)
    @Published var image: UIImage?
    /// 初始化方法
    /// - Parameter phAsset: PHAsset对象
    init(phAsset: PHAsset) {
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
        self.creationDate = phAsset.creationDate
        self.width = CGFloat(phAsset.pixelWidth)
        self.height = CGFloat(phAsset.pixelHeight)
        
        if let cached = CMAssetLoader.shared.cachedImage(for: self, targetSize: targetSize) {
            image = cached
        }
        
        Task {
            await loadImage()
        }
    }
    
    func loadImage() async {
        CMAssetLoader.shared.loadImage(
            for: self,
            targetSize: targetSize
        ) { loadedImage, error in
            guard let loadedImage = loadedImage else {
                return
            }
            self.image = loadedImage
        }
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
