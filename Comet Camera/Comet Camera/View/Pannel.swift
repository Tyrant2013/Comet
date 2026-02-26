//
//  Pannel.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI

struct GaugeView: View {
    // 配置参数
    let minValue: Double = 0.5
    let maxValue: Double = 10.0
    let majorTicks: [Double] = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    
    // 状态
    @State private var currentValue: Double = 0.5
    
    // 几何配置
    let gaugeRadius: CGFloat = 140
    let gaugeThickness: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.7 // 中心点偏下，给半圆留空间
            
            ZStack {
                // 背景圆弧轨道
                ArcTrack(
                    center: CGPoint(x: centerX, y: centerY),
                    radius: gaugeRadius,
                    startAngle: 180,
                    endAngle: 360
                )
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                
                // 刻度
                ForEach(getAllTicks(), id: \.value) { tick in
                    TickView(
                        tick: tick,
                        center: CGPoint(x: centerX, y: centerY),
                        radius: gaugeRadius,
                        isMajor: majorTicks.contains(tick.value)
                    )
                }
                
                // 数值标签
                ForEach(majorTicks, id: \.self) { value in
                    LabelView(
                        value: value,
                        center: CGPoint(x: centerX, y: centerY),
                        radius: gaugeRadius - 35,
                        angle: valueToAngle(value)
                    )
                }
                
                // 指针 - 从中心指向外
                NeedleView(
                    center: CGPoint(x: centerX, y: centerY),
                    angle: valueToAngle(currentValue),
                    length: gaugeRadius - 10
                )
                
                // 中心点
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                    .position(x: centerX, y: centerY)
                
                // 数值显示
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", currentValue))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    
                    Text("当前数值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .position(x: centerX, y: centerY + 50)
            }
        }
        .frame(height: 250)
        .gesture(
            DragGesture()
                .onChanged { value in
                    handleDrag(at: value.location, in: geometryProxy())
                }
        )
    }
    
    // 辅助计算
    func geometryProxy() -> CGSize {
        return CGSize(width: 400, height: 250)
    }
    
    // MARK: - 刻度数据结构
    struct TickData: Identifiable {
        let id = UUID()
        let value: Double
    }
    
    func getAllTicks() -> [TickData] {
        var ticks: [TickData] = []
        
        // 添加所有刻度值（包括大刻度和小刻度）
        for i in 0..<majorTicks.count - 1 {
            let start = majorTicks[i]
            let end = majorTicks[i + 1]
            let step = (end - start) / 6 // 5个小刻度 = 6等分
            
            for j in 0...6 {
                let value = start + step * Double(j)
                // 避免重复添加大刻度
                if j == 0 || j == 6 || !majorTicks.contains(value) {
                    ticks.append(TickData(value: value))
                }
            }
        }
        
        return ticks.sorted { $0.value < $1.value }
    }
    
    // MARK: - 角度转换
    
    // 数值 -> 角度 (0.5对应180°左，10对应360°/0°右)
    func valueToAngle(_ value: Double) -> Double {
        let normalized = normalizeValue(value) // 0.0 到 1.0
        return 180 + normalized * 180 // 180° -> 360°
    }
    
    // 角度 -> 数值
    func angleToValue(_ angle: Double) -> Double {
        // 标准化到 180-360 范围
        var normalizedAngle = angle
        while normalizedAngle < 180 { normalizedAngle += 360 }
        while normalizedAngle > 360 { normalizedAngle -= 360 }
        
        let normalized = (normalizedAngle - 180) / 180 // 0.0 到 1.0
        return denormalizeValue(normalized)
    }
    
    // MARK: - 非线性映射
    
    func normalizeValue(_ value: Double) -> Double {
        if value <= 0.5 { return 0 }
        if value >= 10.0 { return 1 }
        
        let segments = getNormalizedSegments()
        var accumulated: Double = 0
        
        for seg in segments {
            if value >= seg.start && value <= seg.end {
                let local = (value - seg.start) / (seg.end - seg.start)
                return accumulated + local * seg.weight
            }
            accumulated += seg.weight
        }
        return 1
    }
    
    func denormalizeValue(_ normalized: Double) -> Double {
        let segments = getNormalizedSegments()
        var accumulated: Double = 0
        
        for seg in segments {
            let next = accumulated + seg.weight
            if normalized <= next {
                let local = (normalized - accumulated) / seg.weight
                return seg.start + local * (seg.end - seg.start)
            }
            accumulated = next
        }
        return 10.0
    }
    
    struct Segment {
        let start: Double
        let end: Double
        let weight: Double
    }
    
    func getNormalizedSegments() -> [Segment] {
        // 基础宽度单位
        let baseUnit: Double = 1.0
        
        // 计算各区间的原始权重
        var rawWeights: [(Double, Double, Double)] = [] // (start, end, rawWeight)
        
        // 0.5 -> 1.0 (长度0.5，但占一个单位)
        rawWeights.append((0.5, 1.0, baseUnit))
        
        // 1.0 -> 2.0 (长度1.0，占一个单位)
        rawWeights.append((1.0, 2.0, baseUnit))
        
        // 2.0 -> 10.0，每个区间递减80%
        var currentWeight = baseUnit * 0.8
        var start = 2.0
        for _ in 2..<majorTicks.count {
            rawWeights.append((start, start + 1.0, currentWeight))
            currentWeight *= 0.8
            start += 1.0
        }
        
        // 归一化
        let total = rawWeights.reduce(0) { $0 + $1.2 }
        return rawWeights.map { Segment(start: $0.0, end: $0.1, weight: $0.2 / total) }
    }
    
    // MARK: - 手势处理
    func handleDrag(at point: CGPoint, in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height * 0.7
        
        let dx = point.x - centerX
        let dy = point.y - centerY
        
        // 计算角度（标准数学坐标系，0在右边，逆时针增加）
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // 限制在上半圆 (180° 到 360°)
        if angle >= 180 && angle <= 360 {
            let newValue = angleToValue(angle)
            currentValue = min(max(newValue, minValue), maxValue)
        }
    }
}

// MARK: - 子视图组件

struct ArcTrack: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

struct TickView: View {
    let tick: GaugeView.TickData
    let center: CGPoint
    let radius: CGFloat
    let isMajor: Bool
    
    var body: some View {
        let angle = tick.angle * .pi / 180
        let innerR = radius - (isMajor ? 15 : 8)
        let outerR = radius
        
        let x1 = center.x + cos(angle) * innerR
        let y1 = center.y + sin(angle) * innerR
        let x2 = center.x + cos(angle) * outerR
        let y2 = center.y + sin(angle) * outerR
        
        Path { path in
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
        }
        .stroke(isMajor ? Color.primary : Color.gray.opacity(0.6), lineWidth: isMajor ? 2 : 1)
    }
}

struct LabelView: View {
    let value: Double
    let center: CGPoint
    let radius: CGFloat
    let angle: Double
    
    var body: some View {
        let rad = angle * .pi / 180
        let x = center.x + cos(rad) * radius
        let y = center.y + sin(rad) * radius
        
        Text(formatValue(value))
            .font(.system(size: 12, weight: .medium))
            .position(x: x, y: y)
    }
    
    func formatValue(_ v: Double) -> String {
        if v == floor(v) {
            return String(format: "%.0f", v)
        } else {
            return String(format: "%.1f", v)
        }
    }
}

struct NeedleView: View {
    let center: CGPoint
    let angle: Double
    let length: CGFloat
    
    var body: some View {
        // 指针三角形
        let rad = angle * .pi / 180
        let tipX = center.x + cos(rad) * length
        let tipY = center.y + sin(rad) * length
        
        // 垂直于指针的方向
        let perpRad = rad + .pi / 2
        let width: CGFloat = 3
        let baseX1 = center.x + cos(perpRad) * width
        let baseY1 = center.y + sin(perpRad) * width
        let baseX2 = center.x - cos(perpRad) * width
        let baseY2 = center.y - sin(perpRad) * width
        
        Path { path in
            path.move(to: CGPoint(x: tipX, y: tipY))
            path.addLine(to: CGPoint(x: baseX1, y: baseY1))
            path.addLine(to: CGPoint(x: baseX2, y: baseY2))
            path.closeSubpath()
        }
        .fill(Color.red)
        .shadow(radius: 2)
    }
}

extension GaugeView.TickData {
    var angle: Double {
        // 通过GaugeView实例计算角度，这里简化处理
        // 实际应该在父视图中计算好传入
        return 180 + (value - 0.5) / 9.5 * 180 // 临时线性映射
    }
}

// 修正版本 - 使用正确的结构
struct CorrectedGaugeView: View {
    let minValue: Double = 0.5
    let maxValue: Double = 10.0
    let majorTicks: [Double] = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    
    @State private var currentValue: Double = 0.5
    
    let radius: CGFloat = 140
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // 计算所有刻度位置和角度
                let tickData = calculateTicks()
                
                // 绘制刻度
                ForEach(tickData.indices, id: \.self) { i in
                    let tick = tickData[i]
                    TickLine(
                        center: CGPoint(x: 200, y: 180),
                        angle: tick.angle,
                        radius: radius,
                        isMajor: tick.isMajor
                    )
                }
                
                // 绘制标签
                ForEach(majorTicks.indices, id: \.self) { i in
                    let value = majorTicks[i]
                    let angle = valueToAngle(value)
                    LabelText(
                        center: CGPoint(x: 200, y: 180),
                        angle: angle,
                        radius: radius - 30,
                        text: formatLabel(value)
                    )
                }
                
                // 指针
                Needle(
                    center: CGPoint(x: 200, y: 180),
                    angle: valueToAngle(currentValue),
                    length: radius - 5
                )
                
                // 中心点
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                    .position(x: 200, y: 180)
            }
            .frame(width: 400, height: 200)
            .background(Color.white)
            
            // 数值显示
            VStack(spacing: 4) {
                Text(String(format: "%.2f", currentValue))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text("当前数值")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    updateValue(from: gesture.location)
                }
        )
    }
    
    // MARK: - 计算
    
    struct TickInfo {
        let value: Double
        let angle: Double
        let isMajor: Bool
    }
    
    func calculateTicks() -> [TickInfo] {
        var result: [TickInfo] = []
        
        // 添加所有主刻度
        for major in majorTicks {
            result.append(TickInfo(
                value: major,
                angle: valueToAngle(major),
                isMajor: true
            ))
        }
        
        // 添加小刻度
        for i in 0..<majorTicks.count - 1 {
            let start = majorTicks[i]
            let end = majorTicks[i + 1]
            let step = (end - start) / 6
            
            for j in 1...5 {
                let value = start + step * Double(j)
                result.append(TickInfo(
                    value: value,
                    angle: valueToAngle(value),
                    isMajor: false
                ))
            }
        }
        
        return result.sorted { $0.value < $1.value }
    }
    
    func valueToAngle(_ value: Double) -> Double {
        let norm = normalize(value)
        return 180 + norm * 180 // 180°(左) -> 360°/0°(右)
    }
    
    func normalize(_ value: Double) -> Double {
        if value <= 0.5 { return 0 }
        if value >= 10.0 { return 1 }
        
        let segs = segments()
        var acc: Double = 0
        
        for seg in segs {
            if value >= seg.0 && value <= seg.1 {
                let local = (value - seg.0) / (seg.1 - seg.0)
                return acc + local * seg.2
            }
            acc += seg.2
        }
        return 1
    }
    
    func segments() -> [(Double, Double, Double)] {
        // (start, end, weight)
        var segs: [(Double, Double, Double)] = []
        let base: Double = 1.0
        
        segs.append((0.5, 1.0, base))
        segs.append((1.0, 2.0, base))
        
        var w = base * 0.8
        var s = 2.0
        for _ in 2..<majorTicks.count {
            segs.append((s, s + 1.0, w))
            w *= 0.8
            s += 1.0
        }
        
        let total = segs.reduce(0) { $0 + $1.2 }
        return segs.map { ($0.0, $0.1, $0.2 / total) }
    }
    
    func formatLabel(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
    
    func updateValue(from point: CGPoint) {
        let center = CGPoint(x: 200, y: 180)
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        // 只处理上半圆
        guard angle >= 180 && angle <= 360 else { return }
        
        let norm = (angle - 180) / 180
        currentValue = denormalize(norm)
        currentValue = min(max(currentValue, 0.5), 10.0)
    }
    
    func denormalize(_ norm: Double) -> Double {
        let segs = segments()
        var acc: Double = 0
        
        for seg in segs {
            let next = acc + seg.2
            if norm <= next {
                let local = (norm - acc) / seg.2
                return seg.0 + local * (seg.1 - seg.0)
            }
            acc = next
        }
        return 10.0
    }
}

// MARK: - 绘制组件

struct TickLine: View {
    let center: CGPoint
    let angle: Double
    let radius: CGFloat
    let isMajor: Bool
    
    var body: some View {
        let rad = angle * .pi / 180
        let r1 = radius - (isMajor ? 12 : 6)
        let r2 = radius
        
        Path { p in
            p.move(to: CGPoint(
                x: center.x + cos(rad) * r1,
                y: center.y + sin(rad) * r1
            ))
            p.addLine(to: CGPoint(
                x: center.x + cos(rad) * r2,
                y: center.y + sin(rad) * r2
            ))
        }
        .stroke(isMajor ? Color.black : Color.gray, lineWidth: isMajor ? 2 : 1)
    }
}

struct LabelText: View {
    let center: CGPoint
    let angle: Double
    let radius: CGFloat
    let text: String
    
    var body: some View {
        let rad = angle * .pi / 180
        let x = center.x + cos(rad) * radius
        let y = center.y + sin(rad) * radius
        
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.black)
            .position(x: x, y: y)
    }
}

struct Needle: View {
    let center: CGPoint
    let angle: Double
    let length: CGFloat
    
    var body: some View {
        let rad = angle * .pi / 180
        let tip = CGPoint(
            x: center.x + cos(rad) * length,
            y: center.y + sin(rad) * length
        )
        
        // 垂直方向
        let perp = rad + .pi / 2
        let w: CGFloat = 2.5
        
        Path { p in
            p.move(to: tip)
            p.addLine(to: CGPoint(
                x: center.x + cos(perp) * w,
                y: center.y + sin(perp) * w
            ))
            p.addLine(to: CGPoint(
                x: center.x - cos(perp) * w,
                y: center.y - sin(perp) * w
            ))
            p.closeSubpath()
        }
        .fill(Color.red)
    }
}

struct CorrectedGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        CorrectedGaugeView()
    }
}
