//
//  CMPhotoAdjusterView.swift
//  Comet Camera
//

import SwiftUI

struct CMColorAdjustments {
    var brightness: Double = 0.0 // -1.0 to 1.0
    var contrast: Double = 1.0   // 0.0 to 2.0
    var saturation: Double = 1.0 // 0.0 to 2.0
    var warmth: Double = 0.0     // -1.0 to 1.0
    var tint: Double = 0.0       // -1.0 to 1.0
}

struct CMPhotoAdjusterView: View {
    @State private var adjustments = CMColorAdjustments()
    var adjustmentChanged: ((CMColorAdjustments) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            adjustmentSlider(
                title: "亮度",
                value: $adjustments.brightness,
                range: -1.0...1.0,
                defaultValue: 0.0
            )
            
            adjustmentSlider(
                title: "对比度",
                value: $adjustments.contrast,
                range: 0.0...2.0,
                defaultValue: 1.0
            )
            
            adjustmentSlider(
                title: "饱和度",
                value: $adjustments.saturation,
                range: 0.0...2.0,
                defaultValue: 1.0
            )
            
            adjustmentSlider(
                title: "色温",
                value: $adjustments.warmth,
                range: -1.0...1.0,
                defaultValue: 0.0
            )
            
            adjustmentSlider(
                title: "色调",
                value: $adjustments.tint,
                range: -1.0...1.0,
                defaultValue: 0.0
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    private func adjustmentSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        defaultValue: Double
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
            }
            Slider(
                value: value,
                in: range,
                onEditingChanged: { _ in
                    adjustmentChanged?(adjustments)
                }
            )
            .accentColor(.white)
        }
    }
}

#Preview {
    CMPhotoAdjusterView()
        .background(Color.black)
} 
