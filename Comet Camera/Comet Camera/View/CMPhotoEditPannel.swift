//
//  CMPhotoEditPannel.swift
//  Comet Camera
//

import Foundation
import UIKit

// MARK: - 刻度视图
class ScaleView: UIView {
    var configuration: PhotoEditSlider.Configuration
    weak var scrollView: UIScrollView? // 需要知道当前滚动位置
    
    init(configuration: PhotoEditSlider.Configuration, scrollView: UIScrollView, frame: CGRect) {
        self.configuration = configuration
        self.scrollView = scrollView
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
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

// MARK: - 主组件
class PhotoEditSlider: UIView {
    
    struct Configuration {
        var minValue: CGFloat = -100
        var maxValue: CGFloat = 100
        var defaultValue: CGFloat = 0
        var step: CGFloat = 1
        var tickSpacing: CGFloat = 10
        var majorTickInterval: Int = 10
    }
    
    var configuration: Configuration
    var valueChanged: ((CGFloat) -> Void)?
    var valueChangeEnded: ((CGFloat) -> Void)?
    
    private(set) var currentValue: CGFloat = 0
    
    private let scrollView = UIScrollView()
    private var scaleView: ScaleView!
    private let valueLabel = UILabel()
    private let indicatorContainer = UIView()
    private let parameterLabel = UILabel()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private var lastFeedbackValue: CGFloat = 0
    private var isAdjusting = false
    
    private var totalContentWidth: CGFloat {
        let totalTicks = (configuration.maxValue - configuration.minValue) / configuration.step
        return totalTicks * configuration.tickSpacing + bounds.width
    }
    
    private var centerOffsetX: CGFloat {
        return (totalContentWidth - bounds.width) / 2
    }
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.currentValue = configuration.defaultValue
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.configuration = Configuration()
        self.currentValue = 0
        super.init(coder: coder)
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let contentWidth = totalContentWidth
        scrollView.contentSize = CGSize(width: contentWidth, height: scrollView.bounds.height)
        scaleView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: scrollView.bounds.height)
        
        if !scrollView.isDragging && !scrollView.isDecelerating && scrollView.contentOffset.x == 0 {
            setValue(configuration.defaultValue, animated: false)
        }
    }
    
    private func setupUI() {
        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        
        parameterLabel.translatesAutoresizingMaskIntoConstraints = false
        parameterLabel.text = "亮度"
        parameterLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        parameterLabel.textColor = .white.withAlphaComponent(0.8)
        parameterLabel.textAlignment = .center
        container.addSubview(parameterLabel)
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.systemFont(ofSize: 34, weight: .semibold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        valueLabel.text = formatValue(configuration.defaultValue)
        container.addSubview(valueLabel)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = .fast
        container.addSubview(scrollView)
        
        // 创建 ScaleView，传入 scrollView 引用
        scaleView = ScaleView(configuration: configuration, scrollView: scrollView, frame: .zero)
        scaleView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scaleView)
        
        // 中央指示器（仅作为视觉参考，实际高亮由 ScaleView 绘制）
        indicatorContainer.translatesAutoresizingMaskIntoConstraints = false
        indicatorContainer.backgroundColor = .clear
        indicatorContainer.isUserInteractionEnabled = false
        container.addSubview(indicatorContainer)
        
        // 中央指示线（半透明，因为实际高亮在刻度上）
        let centerLine = UIView()
        centerLine.translatesAutoresizingMaskIntoConstraints = false
        centerLine.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
        centerLine.layer.cornerRadius = 1
        indicatorContainer.addSubview(centerLine)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            container.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            parameterLabel.topAnchor.constraint(equalTo: container.topAnchor),
            parameterLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: parameterLabel.bottomAnchor, constant: 8),
            valueLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 50),
            
            indicatorContainer.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 8),
            indicatorContainer.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            indicatorContainer.widthAnchor.constraint(equalToConstant: 40),
            indicatorContainer.heightAnchor.constraint(equalToConstant: 40),
            
            centerLine.centerXAnchor.constraint(equalTo: indicatorContainer.centerXAnchor),
            centerLine.centerYAnchor.constraint(equalTo: indicatorContainer.centerYAnchor),
            centerLine.widthAnchor.constraint(equalToConstant: 2),
            centerLine.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }
    
    private func valueFromOffset(_ offsetX: CGFloat) -> CGFloat {
        let delta = offsetX - centerOffsetX
        let valueDelta = delta / configuration.tickSpacing * configuration.step
        return configuration.defaultValue + valueDelta
    }
    
    private func offsetFromValue(_ value: CGFloat) -> CGFloat {
        let valueDelta = value - configuration.defaultValue
        let delta = valueDelta / configuration.step * configuration.tickSpacing
        return centerOffsetX + delta
    }
    
    func setValue(_ value: CGFloat, animated: Bool) {
        let clampedValue = max(configuration.minValue, min(configuration.maxValue, value))
        currentValue = clampedValue
        valueLabel.text = formatValue(clampedValue)
        
        let offsetX = offsetFromValue(clampedValue)
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
    }
    
    private func formatValue(_ value: CGFloat) -> String {
        if abs(value) < 0.001 { return "0" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int(value))"
    }
    
    @objc private func handleDoubleTap() {
        setValue(configuration.defaultValue, animated: true)
        impactFeedback.impactOccurred()
    }
    
    func setParameterName(_ name: String) {
        parameterLabel.text = name
    }
}

// MARK: - UIScrollViewDelegate
extension PhotoEditSlider: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 关键：每次滚动都重绘刻度，更新透明度和高亮
        scaleView.setNeedsDisplay()
        
        guard !isAdjusting else { return }
        
        let rawValue = valueFromOffset(scrollView.contentOffset.x)
        let steppedValue = round(rawValue / configuration.step) * configuration.step
        let clampedValue = max(configuration.minValue, min(configuration.maxValue, steppedValue))
        
        if abs(currentValue - clampedValue) > 0.001 {
            currentValue = clampedValue
            valueLabel.text = formatValue(clampedValue)
            valueChanged?(clampedValue)
            
            let prevInt = Int(lastFeedbackValue / 10)
            let currInt = Int(clampedValue / 10)
            if prevInt != currInt {
                impactFeedback.impactOccurred()
                lastFeedbackValue = clampedValue
            }
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let targetValue = valueFromOffset(targetContentOffset.pointee.x)
        let steppedValue = round(targetValue / configuration.step) * configuration.step
        let clampedValue = max(configuration.minValue, min(configuration.maxValue, steppedValue))
        
        let targetOffsetX = offsetFromValue(clampedValue)
        targetContentOffset.pointee = CGPoint(x: targetOffsetX, y: 0)
        
        currentValue = clampedValue
        valueLabel.text = formatValue(clampedValue)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            valueChangeEnded?(currentValue)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let currentOffset = scrollView.contentOffset.x
        let currentVal = valueFromOffset(currentOffset)
        let steppedValue = round(currentVal / configuration.step) * configuration.step
        let clampedValue = max(configuration.minValue, min(configuration.maxValue, steppedValue))
        
        let targetOffsetX = offsetFromValue(clampedValue)
        
        if abs(currentOffset - targetOffsetX) > 1 {
            isAdjusting = true
            scrollView.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isAdjusting = false
            }
        }
        
        valueChangeEnded?(clampedValue)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isAdjusting = false
        valueChangeEnded?(currentValue)
    }
}

import SwiftUI

struct EditorTestView: UIViewRepresentable {
    func makeUIView(context: Context) -> PhotoEditSlider {
        let vv = PhotoEditSlider()
        
        return vv
    }
    
    func updateUIView(_ uiView: PhotoEditSlider, context: Context) {
        
    }
}

#Preview {
    EditorTestView()
}
