//
//  CMScaleView.swift
//  Comet Camera
//

import Foundation
import UIKit

// MARK: - 刻度视图
class CMScaleView: UIView {
    var configuration: CMPhotoEditSlider.Configuration
    weak var scrollView: UIScrollView? // 需要知道当前滚动位置
    
    init(configuration: CMPhotoEditSlider.Configuration, scrollView: UIScrollView, frame: CGRect) {
        self.configuration = configuration
        self.scrollView = scrollView
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        print("Rect:", rect)
        
        guard let context = UIGraphicsGetCurrentContext(),
              let scrollView = scrollView else { return }
        
        let totalRange = configuration.maxValue - configuration.minValue
        let totalTicks = Int(totalRange / configuration.step)
        let centerX = bounds.width / 2
        
        // 屏幕中央位置（在 scrollView 坐标系中）
        let screenCenterX = scrollView.contentOffset.x + scrollView.bounds.width / 2
        
        for i in 0...totalTicks {
            let value = configuration.minValue + CGFloat(i) * configuration.step
            let x = centerX + CGFloat(i - totalTicks/2) * configuration.tickSpacing
            
            let isMajor = i % configuration.majorTickInterval == 0
            let isDefault = abs(value - configuration.defaultValue) < 0.001
            
            // 计算该刻度距离屏幕中央的距离
            let distanceFromScreenCenter = abs(x - screenCenterX)
            
            // 渐隐参数：80pt 内完全显示，150pt 外完全消失
            let fadeStart: CGFloat = 60
            let fadeEnd: CGFloat = 140
            let alpha = max(0, min(1, 1 - (distanceFromScreenCenter - fadeStart) / (fadeEnd - fadeStart)))
            
            // 完全透明的跳过绘制
            guard alpha > 0.01 else { continue }
            
            let tickHeight: CGFloat = isMajor ? 20 : (isDefault ? 16 : 12)
            let y: CGFloat = isMajor ? 10 : (isDefault ? 12 : 14)
            
            // 刻度颜色：中央高亮黄色，其他白色
            let isCenter = distanceFromScreenCenter < configuration.tickSpacing / 2
            let color = isCenter ? UIColor.systemYellow : UIColor.white
            
            context.setStrokeColor(color.withAlphaComponent(alpha * (isMajor ? 1.0 : 0.6)).cgColor)
            context.setLineWidth(isMajor ? 2.5 : 1.5)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x, y: y + tickHeight))
            context.strokePath()
            
            // 大刻度数值
            if isMajor {
                let text = "\(Int(value))"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: isCenter ? .semibold : .regular),
                    .foregroundColor: color.withAlphaComponent(alpha * 0.7)
                ]
                let size = text.size(withAttributes: attributes)
                text.draw(at: CGPoint(x: x - size.width/2, y: y + tickHeight + 4), withAttributes: attributes)
            }
        }
    }
}
