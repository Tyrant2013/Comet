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
    
    // 缓存刻度数据避免重复计算
    private var allTicksCache: [TickData] {
        calculateAllTicks()
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
                            let tickX = centerX + tick.offset - currentOffset
                            
                            if abs(tickX - centerX) < visibleWidth / 2 + 30 {
                                TickItem(
                                    tick: tick,
                                    x: tickX,
                                    y: centerY,
                                    distanceFromCenter: abs(tickX - centerX),
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
                            let delta = gesture.location.x - dragStartLocation
                            let newOffset = dragStartOffset - delta
                            
                            let maxOffset = valueToOffset(maxValue)
                            let clampedOffset = max(0, min(newOffset, maxOffset))
                            
                            currentOffset = clampedOffset
                            currentValue = offsetToValue(currentOffset)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.easeOut(duration: 0.15)) {
                            snapToNearestTick()
                        }
                    }
            )
            
            // 数值显示
            VStack(spacing: 8) {
                Text(String(format: "%.2f", currentValue))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text("左右拖动调节")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            currentOffset = 0
        }
    }
    
    // MARK: - 刻度数据
    
    struct TickData: Identifiable {
        let id = UUID()
        let value: Double
        let offset: CGFloat
        let isMajor: Bool
    }
    
    func calculateAllTicks() -> [TickData] {
        var result: [TickData] = []
        let baseUnit: CGFloat = 80
        
        // 0.5
        result.append(TickData(value: 0.5, offset: 0, isMajor: true))
        
        var currentPos: CGFloat = 0
        let width1 = baseUnit
        
        // 0.5 -> 1.0 的小刻度
        for j in 1...5 {
            let ratio = CGFloat(j) / 6.0
            let val = 0.5 + 0.5 * Double(ratio)
            result.append(TickData(value: val, offset: width1 * ratio, isMajor: false))
        }
        
        currentPos += width1
        // 1.0
        result.append(TickData(value: 1.0, offset: currentPos, isMajor: true))
        
        // 1.0 -> 2.0 的小刻度
        for j in 1...5 {
            let ratio = CGFloat(j) / 6.0
            let val = 1.0 + 1.0 * Double(ratio)
            result.append(TickData(value: val, offset: currentPos + width1 * ratio, isMajor: false))
        }
        
        currentPos += width1
        // 2.0
        result.append(TickData(value: 2.0, offset: currentPos, isMajor: true))
        
        // 2.0 -> 10.0 (80%递减)
        var prevWidth = width1
        var lastMajorPos = currentPos
        
        for i in 2..<majorTicks.count - 1 {
            let newWidth = prevWidth * 0.8
            let currentMajor = majorTicks[i]
            let nextMajor = majorTicks[i + 1]
            
            // 小刻度
            for j in 1...5 {
                let ratio = Double(j) / 6.0
                let val = currentMajor + (nextMajor - currentMajor) * ratio
                let pos = lastMajorPos + newWidth * CGFloat(ratio)
                result.append(TickData(value: val, offset: pos, isMajor: false))
            }
            
            lastMajorPos += newWidth
            // 下一个大刻度
            result.append(TickData(value: nextMajor, offset: lastMajorPos, isMajor: true))
            
            prevWidth = newWidth
        }
        
        return result
    }
    
    // MARK: - 转换函数
    
    func valueToOffset(_ value: Double) -> CGFloat {
        let ticks = allTicksCache
        
        if value <= 0.5 { return 0 }
        if value >= 10.0 { return ticks.last?.offset ?? 0 }
        
        for i in 0..<ticks.count - 1 {
            if value >= ticks[i].value && value <= ticks[i + 1].value {
                let t1 = ticks[i]
                let t2 = ticks[i + 1]
                let ratio = CGFloat((value - t1.value) / (t2.value - t1.value))
                return t1.offset + ratio * (t2.offset - t1.offset)
            }
        }
        return 0
    }
    
    func offsetToValue(_ offset: CGFloat) -> Double {
        let ticks = allTicksCache
        
        if offset <= 0 { return 0.5 }
        
        for i in 0..<ticks.count - 1 {
            if offset >= ticks[i].offset && offset <= ticks[i + 1].offset {
                let t1 = ticks[i]
                let t2 = ticks[i + 1]
                let ratio = Double((offset - t1.offset) / (t2.offset - t1.offset))
                return t1.value + (t2.value - t1.value) * ratio
            }
        }
        return 10.0
    }
    
    // MARK: - 吸附到最近的刻度（包括小刻度）
    func snapToNearestTick() {
        let ticks = allTicksCache
        let currentVal = currentValue
        
        // 找到最近的刻度值
        var nearestValue = ticks[0].value
        var minDistance = abs(currentVal - nearestValue)
        
        for tick in ticks {
            let distance = abs(currentVal - tick.value)
            if distance < minDistance {
                minDistance = distance
                nearestValue = tick.value
            }
        }
        
        // 限制范围
        nearestValue = min(max(nearestValue, minValue), maxValue)
        
        currentValue = nearestValue
        currentOffset = valueToOffset(nearestValue)
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
