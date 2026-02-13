//
//  CMCameraZoomDialView.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import UIKit
import SwiftUI
import Combine

public struct CMCameraZoomDialConfiguration: Sendable, Equatable {
    public var anchorValues: [CGFloat]
    public var anchorProgress: [CGFloat]
    public var visibleProgressWindow: CGFloat
    public var horizontalInsetRatio: CGFloat
    public var minHorizontalInset: CGFloat
    public var maxHorizontalInset: CGFloat
    public var snapThresholdDuringDrag: CGFloat
    public var snapThresholdOnEnd: CGFloat
    public var dragTravelScreenRatio: CGFloat
    public var postTwoFirstUnitFactor: CGFloat
    public var postTwoDecay: CGFloat
    
    public init(
        anchorValues: [CGFloat] = [0.5, 1.0, 2.0, 10.0],
        anchorProgress: [CGFloat] = [0.0, 0.06, 0.12, 1.0],
        visibleProgressWindow: CGFloat = 0.56,
        horizontalInsetRatio: CGFloat = 0.09,
        minHorizontalInset: CGFloat = 24,
        maxHorizontalInset: CGFloat = 48,
        snapThresholdDuringDrag: CGFloat = 0.10,
        snapThresholdOnEnd: CGFloat = 0.14,
        dragTravelScreenRatio: CGFloat = 0.5,
        postTwoFirstUnitFactor: CGFloat = 0.5,
        postTwoDecay: CGFloat = 0.75
    ) {
        self.anchorValues = anchorValues
        self.anchorProgress = anchorProgress
        self.visibleProgressWindow = visibleProgressWindow
        self.horizontalInsetRatio = horizontalInsetRatio
        self.minHorizontalInset = minHorizontalInset
        self.maxHorizontalInset = maxHorizontalInset
        self.snapThresholdDuringDrag = snapThresholdDuringDrag
        self.snapThresholdOnEnd = snapThresholdOnEnd
        self.dragTravelScreenRatio = dragTravelScreenRatio
        self.postTwoFirstUnitFactor = postTwoFirstUnitFactor
        self.postTwoDecay = postTwoDecay
    }
    
    public static let `default` = CMCameraZoomDialConfiguration()
    
    func normalized(minValue: CGFloat, maxValue: CGFloat) -> CMCameraZoomDialConfiguration {
        var cfg = self
        
        let count = min(anchorValues.count, anchorProgress.count)
        let pairs = (0..<count).map { idx in
            (anchorValues[idx], anchorProgress[idx])
        }.sorted(by: { $0.0 < $1.0 })
        
        let filtered = pairs.filter { pair in
            pair.0 >= minValue && pair.0 <= maxValue
        }
        
        if filtered.count >= 2 {
            cfg.anchorValues = filtered.map { $0.0 }
            cfg.anchorProgress = filtered.map { min(max($0.1, 0), 1) }
        }
        else {
            cfg.anchorValues = [minValue, maxValue]
            cfg.anchorProgress = [0, 1]
        }
        
        cfg.visibleProgressWindow = max(0.12, min(cfg.visibleProgressWindow, 1.0))
        cfg.horizontalInsetRatio = max(0.02, min(cfg.horizontalInsetRatio, 0.2))
        cfg.minHorizontalInset = max(0, cfg.minHorizontalInset)
        cfg.maxHorizontalInset = max(cfg.minHorizontalInset, cfg.maxHorizontalInset)
        cfg.snapThresholdDuringDrag = max(0, cfg.snapThresholdDuringDrag)
        cfg.snapThresholdOnEnd = max(cfg.snapThresholdDuringDrag, cfg.snapThresholdOnEnd)
        cfg.dragTravelScreenRatio = max(0.2, min(cfg.dragTravelScreenRatio, 0.9))
        cfg.postTwoFirstUnitFactor = max(0.1, min(cfg.postTwoFirstUnitFactor, 1.0))
        cfg.postTwoDecay = max(0.2, min(cfg.postTwoDecay, 0.95))
        return cfg
    }
}

public final class CMCameraZoomDialView: UIView {
    public var onValueChanging: ((CGFloat) -> Void)?
    public var onInteractionBegan: (() -> Void)?
    public var onInteractionEnded: ((CGFloat) -> Void)?
    
    public private(set) var isInteracting: Bool = false
    public private(set) var value: CGFloat = 1.0
    
    public var minValue: CGFloat = 0.5 {
        didSet {
            if minValue > maxValue { maxValue = minValue }
            state.minValue = minValue
            state.configuration = interactionConfiguration.normalized(minValue: minValue, maxValue: maxValue)
            setValue(value, animated: false, notify: false)
        }
    }
    
    public var maxValue: CGFloat = 10.0 {
        didSet {
            if maxValue < minValue { minValue = maxValue }
            state.maxValue = maxValue
            state.configuration = interactionConfiguration.normalized(minValue: minValue, maxValue: maxValue)
            setValue(value, animated: false, notify: false)
        }
    }
    
    public var presetValues: [CGFloat] = [0.5, 1.0, 2.0] {
        didSet {
            state.segmentValues = sanitizeSegmentValues(presetValues)
        }
    }
    
    public var interactionConfiguration: CMCameraZoomDialConfiguration = .default {
        didSet {
            state.configuration = interactionConfiguration.normalized(minValue: minValue, maxValue: maxValue)
        }
    }
    
    private let state = CMZoomSelectorState()
    private var host: UIHostingController<CMZoomSelectorRootView>?
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    public func setValue(_ newValue: CGFloat, animated: Bool, notify: Bool = false) {
        let clamped = max(minValue, min(newValue, maxValue))
        value = clamped
        state.value = clamped
        if notify {
            onValueChanging?(clamped)
        }
    }
    
    private func setupUI() {
        clipsToBounds = false
        backgroundColor = .clear
        
        state.value = value
        state.minValue = minValue
        state.maxValue = maxValue
        state.segmentValues = sanitizeSegmentValues(presetValues)
        state.configuration = interactionConfiguration.normalized(minValue: minValue, maxValue: maxValue)
        
        let root = CMZoomSelectorRootView(
            state: state,
            onInteractionBegan: { [weak self] in
                guard let self else { return }
                self.isInteracting = true
                self.onInteractionBegan?()
            },
            onValueChanging: { [weak self] next in
                guard let self else { return }
                self.value = next
                self.onValueChanging?(next)
            },
            onInteractionEnded: { [weak self] finalValue in
                guard let self else { return }
                self.isInteracting = false
                self.value = finalValue
                self.onInteractionEnded?(finalValue)
            }
        )
        
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.host = host
    }
    
    private func sanitizeSegmentValues(_ values: [CGFloat]) -> [CGFloat] {
        let base = values
            .filter { $0 > 0 }
            .sorted()
        if base.count >= 3 {
            return [base[0], base[1], base[2]]
        }
        return [0.5, 1.0, 2.0]
    }
}

private final class CMZoomSelectorState: ObservableObject {
    @Published var value: CGFloat = 1.0
    @Published var minValue: CGFloat = 0.5
    @Published var maxValue: CGFloat = 10.0
    @Published var segmentValues: [CGFloat] = [0.5, 1.0, 2.0]
    @Published var configuration: CMCameraZoomDialConfiguration = .default
}

private struct CMZoomSelectorRootView: View {
    @ObservedObject var state: CMZoomSelectorState
    
    let onInteractionBegan: () -> Void
    let onValueChanging: (CGFloat) -> Void
    let onInteractionEnded: (CGFloat) -> Void
    
    @State private var isVisible = true
    @State private var showDial = false
    @State private var dragStartProgress: CGFloat = 0
    @State private var isDragging = false
    @State private var autoHideWorkItem: DispatchWorkItem?
    
    private let highlight = Color(red: 1.0, green: 0.86, blue: 0.24)
    
    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            ZStack {
                if isVisible {
                    if showDial {
                        dialContent
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .bottom)),
                                removal: .opacity
                            ))
                    }
                    else {
                        segmentContent
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            ))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(width: width))
            .simultaneousGesture(longPressGesture)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showDial)
        .animation(.easeOut(duration: 0.22), value: isVisible)
    }
    
    private var segmentContent: some View {
        HStack(spacing: 12) {
            ForEach(segmentDisplayValues(), id: \.self) { item in
                Button {
                    showFromInteraction()
                    let clamped = clamp(item)
                    state.value = clamped
                    onValueChanging(clamped)
                    onInteractionEnded(clamped)
                    scheduleAutoHide()
                } label: {
                    Text(zoomText(item))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected(item) ? highlight : .white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(isSelected(item) ? 0.12 : 0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
    
    private var dialContent: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let center = CGPoint(x: width * 0.5, y: height + 30)
            let radius = min(width * 0.56, height + 26)
            let start = -CGFloat.pi * 0.92
            let end = -CGFloat.pi * 0.08
            
            ZStack {
                DialDomeShape(startAngle: start, endAngle: end)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.68),
                                Color.black.opacity(0.52),
                                Color.black.opacity(0.28)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                DialDomeShape(startAngle: start, endAngle: end)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Path { path in
                    for tick in tickMarks(center: center, radius: radius, startAngle: start, endAngle: end).filter({ $0.isMajor }) {
                        path.move(to: tick.start)
                        path.addLine(to: tick.end)
                    }
                }
                .stroke(Color.white.opacity(0.72), lineWidth: 0.78)
                
                Path { path in
                    for tick in tickMarks(center: center, radius: radius, startAngle: start, endAngle: end).filter({ !$0.isMajor }) {
                        path.move(to: tick.start)
                        path.addLine(to: tick.end)
                    }
                }
                .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
                
                ForEach(majorLabelItems(center: center, radius: radius, startAngle: start, endAngle: end), id: \.id) { item in
                    VStack(spacing: 2) {
                        Text(item.zoom)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(item.highlight ? highlight : .white.opacity(0.9))
                        Text(item.mm)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .rotationEffect(.degrees(item.rotationDegrees))
                    .position(item.position)
                }
                
                Path { path in
                    path.move(to: CGPoint(x: width * 0.33, y: 0))
                    path.addLine(to: CGPoint(x: width * 0.33, y: height))
                    path.move(to: CGPoint(x: width * 0.67, y: 0))
                    path.addLine(to: CGPoint(x: width * 0.67, y: height))
                }
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                
                Path { path in
                    path.move(to: CGPoint(x: width * 0.5, y: 0))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height))
                }
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                
                VStack(spacing: 1) {
                    TriangleMarker()
                        .fill(highlight)
                        .frame(width: 10, height: 16)
                    Text(zoomText(state.value))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(highlight)
                    Text(mmText(for: state.value))
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.34))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 6)
            }
            .clipped()
        }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .onEnded { _ in
                showFromInteraction()
                onInteractionBegan()
                showDial = true
                dragStartProgress = progressForValue(state.value)
            }
    }
    
    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { drag in
                showFromInteraction()
                if !isDragging {
                    isDragging = true
                    dragStartProgress = progressForValue(state.value)
                }
                if !showDial {
                    onInteractionBegan()
                    showDial = true
                }
                let dragRange = max(1, width * state.configuration.dragTravelScreenRatio)
                let progress = min(max(dragStartProgress + drag.translation.width / dragRange, 0), 1)
                let next = snappedValue(valueForProgress(progress), threshold: state.configuration.snapThresholdDuringDrag)
                if abs(next - state.value) > 0.0001 {
                    state.value = next
                    onValueChanging(next)
                }
            }
            .onEnded { _ in
                isDragging = false
                let final = snappedValue(state.value, threshold: state.configuration.snapThresholdOnEnd)
                state.value = final
                dragStartProgress = progressForValue(final)
                onValueChanging(final)
                onInteractionEnded(final)
                scheduleAutoHide()
            }
    }
    
    private func showFromInteraction() {
        autoHideWorkItem?.cancel()
        if !isVisible {
            isVisible = true
        }
    }
    
    private func scheduleAutoHide() {
        autoHideWorkItem?.cancel()
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.22)) {
                showDial = false
                isVisible = false
            }
        }
        autoHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }
    
    private func segmentDisplayValues() -> [CGFloat] {
        let base = state.segmentValues.count >= 3 ? state.segmentValues : [0.5, 1.0, 2.0]
        let first = base[0]
        let second = base[1]
        var third = base[2]
        let v = round(state.value * 10) / 10
        let preset = [first, second, base[2]]
        if !preset.contains(where: { abs($0 - v) < 0.05 }) {
            third = v
        }
        return [first, second, third]
    }
    
    private func isSelected(_ value: CGFloat) -> Bool {
        abs(state.value - value) < 0.05
    }
    
    private func clamp(_ value: CGFloat) -> CGFloat {
        max(state.minValue, min(value, state.maxValue))
    }
    
    private func zoomText(_ value: CGFloat) -> String {
        String(format: "%.1fx", value)
    }
    
    private func mmText(for value: CGFloat) -> String {
        let mm = max(13, Int((value * 26).rounded()))
        return "\(mm) MM"
    }
    
    private struct TickMark {
        let start: CGPoint
        let end: CGPoint
        let isMajor: Bool
    }
    
    private struct MajorLabelItem {
        let id: String
        let zoom: String
        let mm: String
        let position: CGPoint
        let rotationDegrees: Double
        let highlight: Bool
    }
    
    private func tickMarks(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat) -> [TickMark] {
        let step: CGFloat = 0.1
        
        var marks: [TickMark] = []
        var v = state.minValue
        while v <= state.maxValue + 0.001 {
            let angle = angleForTick(v, startAngle: startAngle, endAngle: endAngle)
            if angle >= startAngle && angle <= endAngle {
                let rounded = round(v * 10)
                let isMajor = Int(rounded) % 10 == 0 || abs(v - 0.5) < 0.05 || abs(v - 2.0) < 0.05
                let innerOffset: CGFloat = isMajor ? 12 : 6
                
                let p1 = CGPoint(
                    x: center.x + cos(angle) * (radius - innerOffset),
                    y: center.y + sin(angle) * (radius - innerOffset)
                )
                let p2 = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                marks.append(.init(start: p1, end: p2, isMajor: isMajor))
            }
            v += step
        }
        return marks
    }
    
    private func majorLabelItems(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat) -> [MajorLabelItem] {
        let candidates: [CGFloat] = [0.5, 1.0, 2.0, 10.0]
        return candidates.compactMap { value in
            guard value >= state.minValue, value <= state.maxValue else { return nil }
            let angle = angleForTick(value, startAngle: startAngle, endAngle: endAngle)
            guard angle >= startAngle, angle <= endAngle else { return nil }
            
            let position = CGPoint(
                x: center.x + cos(angle) * (radius - 44),
                y: center.y + sin(angle) * (radius - 44)
            )
            let tangent = angle + .pi * 0.5
            let degrees = Double(tangent * 180.0 / .pi)
            
            return MajorLabelItem(
                id: "major_\(value)",
                zoom: majorLabelText(value),
                mm: mmText(for: value),
                position: position,
                rotationDegrees: degrees,
                highlight: abs(value - state.value) < 0.05
            )
        }
    }
    
    private func majorLabelText(_ value: CGFloat) -> String {
        if abs(value - value.rounded()) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
    
    private func angleForTick(_ value: CGFloat, startAngle: CGFloat, endAngle: CGFloat) -> CGFloat {
        let pCurrent = progressForValue(state.value)
        let pTick = progressForValue(value)
        
        // left side should be smaller zoom, right side should be bigger zoom.
        let delta = pTick - pCurrent
        let visibleProgressWindow = state.configuration.visibleProgressWindow
        let angleSpan = endAngle - startAngle
        let angle = -CGFloat.pi * 0.5 + (delta / visibleProgressWindow) * angleSpan
        return angle
    }
    
    private func progressForValue(_ value: CGFloat) -> CGFloat {
        let v = clamp(value)
        if v <= 0.5 { return 0 }
        if v >= 10.0 { return 1 }
        let baseSpan = configuredFirstTwoSpan()
        let p1 = baseSpan
        let p2 = min(0.98, p1 + baseSpan)
        let firstSegmentEase: CGFloat = 1.4
        let secondSegmentEase: CGFloat = 1.2
        
        if v <= 1.0 {
            let t = (v - 0.5) / 0.5
            let clampedT = min(max(t, 0), 1)
            let eased = pow(clampedT, 1 / firstSegmentEase)
            return eased * p1
        }
        if v <= 2.0 {
            let t = v - 1.0
            let clampedT = min(max(t, 0), 1)
            let eased = pow(clampedT, 1 / secondSegmentEase)
            return p1 + eased * (p2 - p1)
        }
        
        let spans = postTwoUnitSpans(startProgress: p2, baseSpan: baseSpan)
        let clamped = min(v, 9.9999)
        let integerPart = Int(floor(clamped))
        let unitIndex = max(0, min(7, integerPart - 2))
        let fractional = clamped - CGFloat(integerPart)
        
        let prefix = spans.prefix(unitIndex).reduce(0, +)
        return p2 + prefix + spans[unitIndex] * fractional
    }
    
    private func valueForProgress(_ progress: CGFloat) -> CGFloat {
        let p = min(max(progress, 0), 1)
        if p <= 0 { return 0.5 }
        if p >= 1 { return 10.0 }
        let baseSpan = configuredFirstTwoSpan()
        let p1 = baseSpan
        let p2 = min(0.98, p1 + baseSpan)
        let firstSegmentEase: CGFloat = 1.4
        let secondSegmentEase: CGFloat = 1.2
        
        if p <= p1 {
            let t = p1 > 0 ? p / p1 : 0
            let eased = pow(min(max(t, 0), 1), firstSegmentEase)
            return 0.5 + eased * 0.5
        }
        if p <= p2 {
            let t = (p - p1) / max(p2 - p1, 0.0001)
            let eased = pow(min(max(t, 0), 1), secondSegmentEase)
            return 1.0 + eased
        }
        
        let spans = postTwoUnitSpans(startProgress: p2, baseSpan: baseSpan)
        var cursor = p2
        for idx in 0..<spans.count {
            let next = cursor + spans[idx]
            if p <= next {
                let t = (p - cursor) / max(spans[idx], 0.0001)
                return CGFloat(2 + idx) + t
            }
            cursor = next
        }
        return 10.0
    }
    
    private func postTwoUnitSpans(startProgress: CGFloat, baseSpan: CGFloat) -> [CGFloat] {
        let remaining = max(0.0001, 1.0 - startProgress)
        let cfg = state.configuration
        
        var weights: [CGFloat] = []
        var w = max(0.0001, baseSpan * cfg.postTwoFirstUnitFactor)
        for _ in 0..<8 {
            weights.append(w)
            w *= cfg.postTwoDecay
        }
        
        var spans = weights
        let total = spans.reduce(0, +)
        let scale = remaining / max(total, 0.0001)
        spans = spans.map { $0 * scale }
        
        // remove numeric drift so the last major tick can align exactly at 10.0
        let diff = remaining - spans.reduce(0, +)
        if let last = spans.indices.last {
            spans[last] += diff
        }
        return spans
    }
    
    private func configuredFirstTwoSpan() -> CGFloat {
        let p05 = progressAtAnchor(0.5)
        let p10 = progressAtAnchor(1.0)
        let p20 = progressAtAnchor(2.0)
        
        let span01 = max(0.01, p10 - p05)
        let span12 = max(0.01, p20 - p10)
        let base = min(span01, span12)
        let compressed = base * 0.65
        // keep both first segments equal and visibly tighter than before
        return max(0.02, min(0.10, compressed))
    }
    
    private func progressAtAnchor(_ value: CGFloat) -> CGFloat {
        let anchorValues = state.configuration.anchorValues
        let anchorProgress = state.configuration.anchorProgress
        guard anchorValues.count >= 2, anchorValues.count == anchorProgress.count else { return 0 }
        
        let v = min(max(value, anchorValues.first ?? value), anchorValues.last ?? value)
        for idx in 0..<(anchorValues.count - 1) {
            let v0 = anchorValues[idx]
            let v1 = anchorValues[idx + 1]
            guard v >= v0, v <= v1 else { continue }
            let p0 = anchorProgress[idx]
            let p1 = anchorProgress[idx + 1]
            let t = (v - v0) / max(v1 - v0, 0.0001)
            return p0 + t * (p1 - p0)
        }
        return v <= anchorValues[0] ? anchorProgress[0] : anchorProgress[anchorProgress.count - 1]
    }
    
    private func snappedValue(_ value: CGFloat, threshold: CGFloat) -> CGFloat {
        let clamped = clamp(value)
        
        // keep boundaries sticky to avoid 0.5<->1.0 and right-end bounce
        if clamped <= state.minValue + max(0.08, threshold * 2.2) {
            return state.minValue
        }
        if clamped >= state.maxValue - max(0.08, threshold * 2.2) {
            return state.maxValue
        }
        
        let candidates: [CGFloat] = [0.5, 1.0, 2.0]
        for target in candidates {
            guard target >= state.minValue, target <= state.maxValue else { continue }
            var effectiveThreshold = threshold
            if abs(target - 1.0) < 0.001 && state.value <= state.minValue + 0.05 {
                // when leaving 0.5, avoid instantly jumping to 1.0
                effectiveThreshold = min(effectiveThreshold, 0.03)
            }
            if abs(clamped - target) <= effectiveThreshold {
                return target
            }
        }
        return clamped
    }
}

private struct DialDomeShape: Shape {
    let startAngle: CGFloat
    let endAngle: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY + 30)
        let radius = min(rect.width * 0.56, rect.height + 26)
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(radians: Double(startAngle)),
            endAngle: Angle(radians: Double(endAngle)),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TriangleMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
