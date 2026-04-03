//
//  CMRulerLayout.swift
//  Comet Camera
//

import Foundation
import UIKit

// MARK: - 刻度盘布局
final class CMRulerLayout: UICollectionViewFlowLayout {
    
    var itemWidth: CGFloat = 2
    var itemSpacing: CGFloat = 10
    var edgePadding: CGFloat = 0
    
    // 肉卷效果配置
    var fadeEffectEnabled: Bool = true
    var fadeDistance: CGFloat = 150 // 开始淡出的距离（从中心点算）
    var minScale: CGFloat = 0.5     // 最小缩放比例
    var minAlpha: CGFloat = 0.3     // 最小透明度
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: collectionView?.bounds.height ?? 0)
    }
    
    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }
        
        cache.removeAll()
        scrollDirection = .horizontal
        minimumLineSpacing = itemSpacing
        itemSize = CGSize(width: itemWidth, height: collectionView.bounds.height)
        
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        let itemsWidth = CGFloat(numberOfItems) * itemWidth
        let spacingWidth = CGFloat(numberOfItems - 1) * itemSpacing
        contentWidth = edgePadding * 2 + itemsWidth + spacingWidth
        
        for item in 0..<numberOfItems {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            let x = edgePadding + CGFloat(item) * (itemWidth + itemSpacing)
            attributes.frame = CGRect(x: x, y: 0, width: itemWidth, height: collectionView.bounds.height)
            cache.append(attributes)
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard fadeEffectEnabled, let collectionView = collectionView else {
            return cache.filter { $0.frame.intersects(rect) }
        }
        
        let centerX = collectionView.contentOffset.x + collectionView.bounds.width / 2
        
        return cache.filter { $0.frame.intersects(rect) }.map { attributes in
            let copy = attributes.copy() as! UICollectionViewLayoutAttributes
            applyFadeEffect(to: copy, centerX: centerX)
            return copy
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cache.count else { return nil }
        
        let attributes = cache[indexPath.item]
        
        guard fadeEffectEnabled, let collectionView = collectionView else {
            return attributes
        }
        
        let centerX = collectionView.contentOffset.x + collectionView.bounds.width / 2
        let copy = attributes.copy() as! UICollectionViewLayoutAttributes
        applyFadeEffect(to: copy, centerX: centerX)
        return copy
    }
    
    private func applyFadeEffect(to attributes: UICollectionViewLayoutAttributes, centerX: CGFloat) {
        let itemCenterX = attributes.center.x
        let distance = abs(itemCenterX - centerX)
        
        // 计算效果因子 (0 ~ 1)
        let factor = min(1, max(0, distance / fadeDistance))
        
        // 应用缩放和透明度
        let scale = 1 - (factor * (1 - minScale))
        let alpha = 1 - (factor * (1 - minAlpha))
        
        attributes.transform = CGAffineTransform(scaleX: 1, y: scale)
        attributes.alpha = alpha
        // 保持底部对齐的缩放效果
        attributes.center.y = attributes.center.y + (attributes.bounds.height * (1 - scale)) / 2
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else { return proposedContentOffset }
        
        let targetX = proposedContentOffset.x + collectionView.bounds.width / 2
        let itemWidthPlusSpacing = itemWidth + itemSpacing
        let index = round((targetX - edgePadding - itemWidth / 2) / itemWidthPlusSpacing)
        let clampedIndex = max(0, min(CGFloat(cache.count - 1), index))
        let newOffset = edgePadding + clampedIndex * itemWidthPlusSpacing - collectionView.bounds.width / 2 + itemWidth / 2
        
        return CGPoint(x: newOffset, y: 0)
    }
    
    // 支持 bounds 变化时重新计算效果
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return fadeEffectEnabled
    }
}
