import SwiftUI

struct LensSelectorView: View {
    let presetValues: [Double] = [0.5, 1.0, 2.0]
    
    @State private var selectedValue: Double = 0.5
    @State private var isDragging: Bool = false
    @State private var dragStartLocation: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var currentOffset: CGFloat = 0
    
    let buttonWidth: CGFloat = 80
    let buttonHeight: CGFloat = 50
    let gaugeHeight: CGFloat = 120
    let visibleWidth: CGFloat = 240
    let centerY: CGFloat = 60
    let buttonSpacing: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                gestureDetectionLayer
                
                if isDragging {
                    gaugeView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    buttonsView
                        .transition(.opacity.combined(with: .scale))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isDragging)
            .frame(width: visibleWidth, height: max(buttonHeight, gaugeHeight))
            
            Text("当前 Lens: \(String(format: "%.1f", selectedValue))")
                .font(.headline)
        }
        .padding()
    }
    
    // MARK: - 手势检测层
    var gestureDetectionLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onChanged { gesture in
                        // 检查是否在按钮区域内开始拖动
                        let buttonFrame = calculateButtonsFrame()
                        let startY = (max(buttonHeight, gaugeHeight) - buttonHeight) / 2
                        
                        // 只有在按钮区域内才开始拖动
                        if !isDragging {
                            if gesture.location.y >= startY && gesture.location.y <= startY + buttonHeight &&
                               gesture.location.x >= buttonFrame.minX && gesture.location.x <= buttonFrame.maxX {
                                isDragging = true
                                dragStartLocation = gesture.location.x
                                dragStartOffset = valueToOffset(selectedValue)
                                currentOffset = dragStartOffset
                            }
                        } else {
                            // 已经在拖动中，更新值
                            let delta = (gesture.location.x - dragStartLocation) / visibleWidth
                            var newOffset = dragStartOffset - delta
                            newOffset = max(0, min(newOffset, 1))
                            
                            currentOffset = newOffset
                            let rawValue = offsetToValue(currentOffset)
                            selectedValue = round(rawValue * 10) / 10
                        }
                    }
                    .onEnded { _ in
                        guard isDragging else { return }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = false
                            }
                        }
                    }
            )
            .onTapGesture { location in
                guard !isDragging else { return }
                
                // 检查是否在按钮区域内
                let buttonFrame = calculateButtonsFrame()
                let startY = (max(buttonHeight, gaugeHeight) - buttonHeight) / 2
                
                // Y坐标必须在按钮高度内
                guard location.y >= startY && location.y <= startY + buttonHeight else { return }
                // X坐标必须在按钮总宽度内
                guard location.x >= buttonFrame.minX && location.x <= buttonFrame.maxX else { return }
                
                // 判断点击了哪个按钮
                for (index, value) in presetValues.enumerated() {
                    let buttonMinX = buttonFrame.minX + CGFloat(index) * (buttonWidth + buttonSpacing)
                    let buttonMaxX = buttonMinX + buttonWidth
                    
                    if location.x >= buttonMinX && location.x <= buttonMaxX {
                        withAnimation(.spring()) {
                            selectedValue = value
                        }
                        break
                    }
                }
            }
    }
    
    // 计算按钮区域的总frame
    func calculateButtonsFrame() -> CGRect {
        let totalWidth = CGFloat(presetValues.count) * buttonWidth + CGFloat(presetValues.count - 1) * buttonSpacing
        let startX = (visibleWidth - totalWidth) / 2
        let startY = (max(buttonHeight, gaugeHeight) - buttonHeight) / 2
        
        return CGRect(
            x: startX,
            y: startY,
            width: totalWidth,
            height: buttonHeight
        )
    }
    
    // MARK: - 按钮视图
    var buttonsView: some View {
        let totalWidth = CGFloat(presetValues.count) * buttonWidth + CGFloat(presetValues.count - 1) * buttonSpacing
        
        return HStack(spacing: buttonSpacing) {
            ForEach(presetValues.indices, id: \.self) { index in
                let presetValue = presetValues[index]
                let isSelected = isPresetValue(selectedValue) && abs(selectedValue - presetValue) < 0.01
                let isCustomButton = index == 2 && !isPresetValue(selectedValue)
                
                Text(isCustomButton ? String(format: "%.1f", selectedValue) : String(format: "%.1f", presetValue))
                    .font(.system(size: 16, weight: isSelected || isCustomButton ? .bold : .medium))
                    .foregroundColor(isSelected || isCustomButton ? .white : .primary)
                    .frame(width: buttonWidth, height: buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected || isCustomButton ? Color.blue : Color.gray.opacity(0.2))
                    )
            }
        }
        .frame(width: totalWidth)
    }
    
    // MARK: - 刻度盘视图
    var gaugeView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 4)
            
            HStack(spacing: 0) {
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0), .white]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: visibleWidth * 0.15)
                
                Color.clear.frame(width: visibleWidth * 0.7)
                
                LinearGradient(
                    gradient: Gradient(colors: [.white, .white.opacity(0)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: visibleWidth * 0.15)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let ticks = allTicksCache
                
                ZStack {
                    ForEach(ticks) { tick in
                        let displayX = centerX + (tick.offset - currentOffset) * visibleWidth
                        
                        if abs(displayX - centerX) < visibleWidth / 2 + 20 {
                            TickView(
                                tick: tick,
                                x: displayX,
                                y: centerY,
                                dist: abs(displayX - centerX),
                                maxDist: visibleWidth / 2
                            )
                        }
                    }
                    
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.red).frame(width: 2, height: 25)
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                    }
                    .position(x: centerX, y: centerY)
                }
            }
        }
        .frame(width: visibleWidth, height: gaugeHeight)
    }
    
    func isPresetValue(_ value: Double) -> Bool {
        presetValues.contains { abs($0 - value) < 0.01 }
    }
    
    struct TickData: Identifiable {
        let id = UUID()
        let value: Double
        let offset: CGFloat
        let isMajor: Bool
    }
    
    var allTicksCache: [TickData] {
        var result: [TickData] = []
        let weights = calculateWeights()
        var pos: CGFloat = 0
        
        result.append(TickData(value: 0.5, offset: 0, isMajor: true))
        
        for i in 1...4 {
            let v = 0.5 + Double(i) * 0.1
            let p = weights[0] * CGFloat(i) / 5.0
            result.append(TickData(value: v, offset: p, isMajor: false))
        }
        pos += weights[0]
        result.append(TickData(value: 1.0, offset: pos, isMajor: true))
        
        for i in 1...4 {
            let v = 1.0 + Double(i) * 0.2
            let p = pos + weights[1] * CGFloat(i) / 5.0
            result.append(TickData(value: v, offset: p, isMajor: false))
        }
        pos += weights[1]
        result.append(TickData(value: 2.0, offset: pos, isMajor: true))
        
        var w = weights[1]
        for idx in 2..<10 {
            w *= 0.8
            let start = Double(idx)
            for i in 1...4 {
                let v = start + Double(i) * 0.2
                let p = pos + w * CGFloat(i) / 5.0
                result.append(TickData(value: v, offset: p, isMajor: false))
            }
            pos += w
            result.append(TickData(value: Double(idx + 1), offset: pos, isMajor: true))
        }
        
        return result
    }
    
    func calculateWeights() -> [CGFloat] {
        var raw: [CGFloat] = [1.0, 1.0]
        var cur: CGFloat = 0.8
        for _ in 2..<10 {
            raw.append(cur)
            cur *= 0.8
        }
        let total = raw.reduce(0, +)
        return raw.map { $0 / total }
    }
    
    func offsetToValue(_ offset: CGFloat) -> Double {
        if offset <= 0 { return 0.5 }
        if offset >= 1 { return 10.0 }
        
        let ticks = allTicksCache
        for i in 0..<ticks.count-1 {
            let t1 = ticks[i], t2 = ticks[i+1]
            if offset >= t1.offset && offset <= t2.offset {
                let r = Double((offset - t1.offset) / (t2.offset - t1.offset))
                return round((t1.value + (t2.value - t1.value) * r) * 10) / 10
            }
        }
        return 10.0
    }
    
    func valueToOffset(_ value: Double) -> CGFloat {
        if value <= 0.5 { return 0 }
        if value >= 10.0 { return 1 }
        
        let ticks = allTicksCache
        for i in 0..<ticks.count-1 {
            let t1 = ticks[i], t2 = ticks[i+1]
            if value >= t1.value && value <= t2.value {
                let r = CGFloat((value - t1.value) / (t2.value - t1.value))
                return t1.offset + r * (t2.offset - t1.offset)
            }
        }
        return 1
    }
}

struct TickView: View {
    let tick: LensSelectorView.TickData
    let x: CGFloat
    let y: CGFloat
    let dist: CGFloat
    let maxDist: CGFloat
    
    var body: some View {
        let n = dist / maxDist
        let opacity = Double(max(0.15, 1.0 - n))
        let scale = CGFloat(max(0.7, 1.0 - n * 0.3))
        
        VStack(spacing: 2) {
            Rectangle()
                .fill(tick.isMajor ? Color.black.opacity(opacity) : Color.gray.opacity(opacity))
                .frame(width: tick.isMajor ? 2 : 1, height: tick.isMajor ? 18 : 10)
            
            if tick.isMajor {
                Text(String(format: tick.value == floor(tick.value) ? "%.0f" : "%.1f", tick.value))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black.opacity(opacity))
            }
        }
        .scaleEffect(scale)
        .position(x: x, y: y)
    }
}

struct LensSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        LensSelectorView()
    }
}
