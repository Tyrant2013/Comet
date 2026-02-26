//
//  CCTickItem.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/26.
//

import SwiftUI

struct CCTickItem: View {
    let tick: CCLensHorizontalPicker.TickData
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
