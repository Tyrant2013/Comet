import SwiftUI

struct CenterSelectGaugeView: View {
    // 配置参数
    let minValue: Double = 0.5
    let maxValue: Double = 10.0
    let majorTicks: [Double] = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    
    @State private var currentValue: Double = 0.5
    
    // 布局参数
    let visibleWidth: CGFloat = 200
    let gaugeHeight: CGFloat = 150
    let centerY: CGFloat = 80
    
    // 手势状态
    @State private var isDragging: Bool = false
    @State private var dragStartLocation: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    
    @State private var currentOffset: CGFloat = 0
    
    // 步进值
    let step: Double = 0.1
    
    // 总刻度宽度
    private var totalTicksWidth: CGFloat {
        return visibleWidth
    }
    
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                // 渐变遮罩
                HStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0), .white]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: visibleWidth * 0.2)
                    
                    Color.clear.frame(width: visibleWidth * 0.6)
                    
                    LinearGradient(
                        gradient: Gradient(colors: [.white, .white.opacity(0)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: visibleWidth * 0.2)
                }
                
                // 刻度层
                GeometryReader { geo in
                    let centerX = geo.size.width / 2
                    let allTicks = allTicksCache
                    
                    ZStack {
                        ForEach(allTicks.indices, id: \.self) { i in
                            let tick = allTicks[i]
                            let displayX = centerX + (tick.offset - currentOffset) * totalTicksWidth
                            
                            if abs(displayX - centerX) < visibleWidth / 2 + 20 {
                                TickItem(
                                    tick: tick,
                                    x: displayX,
                                    y: centerY,
                                    distanceFromCenter: abs(displayX - centerX),
                                    maxVisibleDistance: visibleWidth / 2
                                )
                            }
                        }
                        
                        // 中央指示器
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 30)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                        }
                        .position(x: centerX, y: centerY)
                    }
                }
            }
            .frame(width: visibleWidth, height: gaugeHeight)
            .clipped()
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartLocation = gesture.location.x
                            dragStartOffset = currentOffset
                        } else {
                            let delta = (gesture.location.x - dragStartLocation) / totalTicksWidth
                            var newOffset = dragStartOffset - delta
                            newOffset = max(0, min(newOffset, 1))
                            
                            currentOffset = newOffset
                            
                            // 转换为值并量化到0.1
                            let rawValue = offsetToValue(currentOffset)
                            currentValue = round(rawValue * 10) / 10
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        // 吸附到最近的0.1
                        let snapped = round(currentValue * 10) / 10
                        currentValue = min(max(snapped, minValue), maxValue)
                        currentOffset = valueToOffset(currentValue)
                    }
            )
            
            // 数值显示
            VStack(spacing: 8) {
                Text(String(format: "%.1f", currentValue))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text("左右拖动调节")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            currentOffset = 0
            currentValue = 0.5
        }
    }
    
    // MARK: - 刻度数据
    
    struct TickData: Identifiable {
        let id = UUID()
        let value: Double
        let offset: CGFloat
        let isMajor: Bool
    }
    
    private var allTicksCache: [TickData] {
        calculateAllTicks()
    }
    
    func calculateAllTicks() -> [TickData] {
        var result: [TickData] = []
        let weights = calculateWeights()
        
        var currentNormalizedPos: CGFloat = 0
        
        // 0.5
        result.append(TickData(value: 0.5, offset: 0, isMajor: true))
        
        // 0.5 -> 1.0 (步进0.1：0.6, 0.7, 0.8, 0.9)
        let weight_0_5_1 = weights[0]
        for i in 1...4 {
            let val = 0.5 + Double(i) * 0.1
            let pos = currentNormalizedPos + weight_0_5_1 * CGFloat(i) / 5.0
            result.append(TickData(value: val, offset: pos, isMajor: false))
        }
        currentNormalizedPos += weight_0_5_1
        result.append(TickData(value: 1.0, offset: currentNormalizedPos, isMajor: true))
        
        // 1.0 -> 2.0 (步进0.2显示：1.2, 1.4, 1.6, 1.8)
        let weight_1_2 = weights[1]
        for i in 1...4 {
            let val = 1.0 + Double(i) * 0.2
            let pos = currentNormalizedPos + weight_1_2 * CGFloat(i) / 5.0
            result.append(TickData(value: val, offset: pos, isMajor: false))
        }
        currentNormalizedPos += weight_1_2
        result.append(TickData(value: 2.0, offset: currentNormalizedPos, isMajor: true))
        
        // 2.0 -> 10.0
        for idx in 2..<majorTicks.count - 1 {
            let weight = weights[idx]
            let startVal = majorTicks[idx]
            
            for i in 1...4 {
                let val = startVal + Double(i) * 0.2
                let pos = currentNormalizedPos + weight * CGFloat(i) / 5.0
                result.append(TickData(value: val, offset: pos, isMajor: false))
            }
            
            currentNormalizedPos += weight
            let endVal = majorTicks[idx + 1]
            result.append(TickData(value: endVal, offset: currentNormalizedPos, isMajor: true))
        }
        
        return result
    }
    
    func calculateWeights() -> [CGFloat] {
        var rawWeights: [CGFloat] = []
        let base: CGFloat = 1.0
        
        rawWeights.append(base) // 0.5-1.0
        rawWeights.append(base) // 1.0-2.0
        
        var current = base * 0.8
        for _ in 2..<majorTicks.count - 1 {
            rawWeights.append(current)
            current *= 0.8
        }
        
        let total = rawWeights.reduce(0, +)
        return rawWeights.map { $0 / total }
    }
    
    // MARK: - 转换函数
    
    func offsetToValue(_ offset: CGFloat) -> Double {
        if offset <= 0 { return 0.5 }
        if offset >= 1 { return 10.0 }
        
        let ticks = allTicksCache
        
        for i in 0..<ticks.count - 1 {
            let t1 = ticks[i]
            let t2 = ticks[i + 1]
            
            if offset >= t1.offset && offset <= t2.offset {
                let ratio = Double((offset - t1.offset) / (t2.offset - t1.offset))
                let rawValue = t1.value + (t2.value - t1.value) * ratio
                // 量化到0.1
                return round(rawValue * 10) / 10
            }
        }
        
        return 10.0
    }
    
    func valueToOffset(_ value: Double) -> CGFloat {
        if value <= 0.5 { return 0 }
        if value >= 10.0 { return 1 }
        
        let ticks = allTicksCache
        
        for i in 0..<ticks.count - 1 {
            let t1 = ticks[i]
            let t2 = ticks[i + 1]
            
            if value >= t1.value && value <= t2.value {
                let ratio = CGFloat((value - t1.value) / (t2.value - t1.value))
                return t1.offset + ratio * (t2.offset - t1.offset)
            }
        }
        
        return 1
    }
}

struct TickItem: View {
    let tick: CenterSelectGaugeView.TickData
    let x: CGFloat
    let y: CGFloat
    let distanceFromCenter: CGFloat
    let maxVisibleDistance: CGFloat
    
    var body: some View {
        let normalizedDist = distanceFromCenter / maxVisibleDistance
        let opacity = Double(max(0.1, 1.0 - normalizedDist))
        let scale = CGFloat(max(0.6, 1.0 - normalizedDist * 0.4))
        
        VStack(spacing: 2) {
            Rectangle()
                .fill(tick.isMajor ? Color.black.opacity(opacity) : Color.gray.opacity(opacity))
                .frame(width: tick.isMajor ? 2 : 1, height: tick.isMajor ? 20 : 10)
            
            if tick.isMajor {
                Text(formatValue(tick.value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black.opacity(opacity))
            }
        }
        .scaleEffect(scale)
        .position(x: x, y: y)
    }
    
    func formatValue(_ v: Double) -> String {
        v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

struct CenterSelectGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        CenterSelectGaugeView()
    }
}
