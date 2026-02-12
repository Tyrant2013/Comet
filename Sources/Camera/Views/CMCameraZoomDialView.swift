//
//  CMCameraZoomDialView.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import UIKit

public final class CMCameraZoomDialView: UIView {
    public var onValueChanging: ((CGFloat) -> Void)?
    public var onInteractionBegan: (() -> Void)?
    public var onInteractionEnded: ((CGFloat) -> Void)?
    
    public private(set) var isInteracting: Bool = false
    
    public var minValue: CGFloat = 1.0 {
        didSet {
            if minValue > maxValue { maxValue = minValue }
            setValue(value, animated: false, notify: false)
            setNeedsLayout()
        }
    }
    
    public var maxValue: CGFloat = 10.0 {
        didSet {
            if maxValue < minValue { minValue = maxValue }
            setValue(value, animated: false, notify: false)
            setNeedsLayout()
        }
    }
    
    public private(set) var value: CGFloat = 1.0
    
    public var presetValues: [CGFloat] = [] {
        didSet { rebuildPresetLabels() }
    }
    
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let ticksLayer = CAShapeLayer()
    private let thumbView = UIView()
    private var presetLabels: [UILabel] = []
    
    // Upper semi-arc: left -> right.
    private let startAngle: CGFloat = -CGFloat.pi * 0.92
    private let endAngle: CGFloat = -CGFloat.pi * 0.08
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
        layoutPresetLabels()
    }
    
    public func setValue(_ newValue: CGFloat, animated: Bool, notify: Bool = false) {
        let clamped = max(minValue, min(newValue, maxValue))
        value = clamped
        updateLayers()
        
        if notify {
            onValueChanging?(clamped)
        }
        
        guard animated else { return }
        thumbView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
        UIView.animate(withDuration: 0.14) {
            self.thumbView.transform = .identity
        }
    }
    
    private func setupUI() {
        isOpaque = false
        backgroundColor = UIColor(white: 1.0, alpha: 0.06)
        layer.cornerRadius = 16
        layer.masksToBounds = true
        
        trackLayer.strokeColor = UIColor(white: 1.0, alpha: 0.22).cgColor
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = 5
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = 5
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
        
        ticksLayer.strokeColor = UIColor(white: 1, alpha: 0.38).cgColor
        ticksLayer.fillColor = UIColor.clear.cgColor
        ticksLayer.lineWidth = 2
        ticksLayer.lineCap = .round
        layer.addSublayer(ticksLayer)
        
        thumbView.backgroundColor = .white
        thumbView.layer.cornerRadius = 13
        thumbView.layer.shadowColor = UIColor.black.cgColor
        thumbView.layer.shadowOpacity = 0.24
        thumbView.layer.shadowRadius = 6
        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(thumbView)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    private func centerPoint() -> CGPoint {
        CGPoint(x: bounds.midX, y: bounds.maxY - 8)
    }
    
    private func radius() -> CGFloat {
        min(bounds.width * 0.44, bounds.height - 20)
    }
    
    private func angle(for value: CGFloat) -> CGFloat {
        guard maxValue > minValue else { return startAngle }
        let n = (value - minValue) / (maxValue - minValue)
        return startAngle + (endAngle - startAngle) * n
    }
    
    private func value(for angle: CGFloat) -> CGFloat {
        let n = (angle - startAngle) / (endAngle - startAngle)
        return minValue + max(0, min(1, n)) * (maxValue - minValue)
    }
    
    private func clampedAngle(_ raw: CGFloat) -> CGFloat {
        return min(endAngle, max(startAngle, raw))
    }
    
    private func normalizedRawAngle(_ raw: CGFloat) -> CGFloat {
        // atan2 output is [-pi, pi]. Pick the equivalent angle closest to the
        // dial arc center to avoid wrap jumps on both left and right ends.
        let center = (startAngle + endAngle) * 0.5
        let twoPi = 2 * CGFloat.pi
        let candidates = [raw - twoPi, raw, raw + twoPi]
        return candidates.min(by: { abs($0 - center) < abs($1 - center) }) ?? raw
    }
    
    private func point(for angle: CGFloat) -> CGPoint {
        let c = centerPoint()
        let r = radius()
        return CGPoint(x: c.x + cos(angle) * r, y: c.y + sin(angle) * r)
    }
    
    private func updateLayers() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let c = centerPoint()
        let r = radius()
        
        trackLayer.path = UIBezierPath(
            arcCenter: c,
            radius: r,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        ).cgPath
        
        let currentAngle = angle(for: value)
        progressLayer.path = UIBezierPath(
            arcCenter: c,
            radius: r,
            startAngle: startAngle,
            endAngle: currentAngle,
            clockwise: true
        ).cgPath
        
        let ticksPath = UIBezierPath()
        for mark in presetValues {
            let markAngle = angle(for: mark)
            let p1 = CGPoint(x: c.x + cos(markAngle) * (r - 8), y: c.y + sin(markAngle) * (r - 8))
            let p2 = CGPoint(x: c.x + cos(markAngle) * (r + 2), y: c.y + sin(markAngle) * (r + 2))
            ticksPath.move(to: p1)
            ticksPath.addLine(to: p2)
        }
        ticksLayer.path = ticksPath.cgPath
        
        let thumbCenter = point(for: currentAngle)
        thumbView.bounds = CGRect(x: 0, y: 0, width: 26, height: 26)
        thumbView.center = thumbCenter
    }
    
    private func rebuildPresetLabels() {
        for label in presetLabels {
            label.removeFromSuperview()
        }
        presetLabels = []
        
        for value in presetValues {
            let label = UILabel()
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(white: 0.95, alpha: 1)
            label.textAlignment = .center
            label.text = String(format: "%.1fx", value)
            addSubview(label)
            presetLabels.append(label)
        }
        setNeedsLayout()
    }
    
    private func layoutPresetLabels() {
        guard presetLabels.count == presetValues.count else { return }
        for (index, mark) in presetValues.enumerated() {
            let angle = self.angle(for: mark)
            let p = point(for: angle)
            let size = CGSize(width: 42, height: 16)
            presetLabels[index].frame = CGRect(
                x: p.x - size.width / 2,
                y: p.y - size.height - 10,
                width: size.width,
                height: size.height
            )
        }
    }
    
    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        onInteractionBegan?()
        applyInteraction(at: location, ended: true)
        onInteractionEnded?(value)
    }
    
    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            isInteracting = true
            onInteractionBegan?()
            applyInteraction(at: location, ended: false)
        case .changed:
            applyInteraction(at: location, ended: false)
        case .ended, .cancelled, .failed:
            applyInteraction(at: location, ended: true)
            isInteracting = false
            onInteractionEnded?(value)
        default:
            break
        }
    }
    
    private func applyInteraction(at location: CGPoint, ended: Bool) {
        let c = centerPoint()
        let raw = normalizedRawAngle(atan2(location.y - c.y, location.x - c.x))
        let clamped = clampedAngle(raw)
        let nextValue = value(for: clamped)
        setValue(nextValue, animated: ended, notify: true)
    }
}
