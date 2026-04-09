//
//  CMPhotoAdjustItem.swift
//  Comet Camera
//

import Foundation
import UIKit

struct CMPhotoAdjustItem: Identifiable, Equatable {
    var id: CMPhotoAdjustType
    let title: String
}

enum CMPhotoAdjustType: Identifiable {
    var id: Self { self }
    case brightness
    case contrast
    case saturation
    case white
    case tone
    case hsl
    case fade
    case highlights
    case shadows
    case sharpen
    case vignette
    case blur
    case clarity
}

extension CMPhotoAdjustItem {
    static func supportedAdjustItems() -> [CMPhotoAdjustItem] {
        [
            CMPhotoAdjustItem(id: .brightness, title: "亮度"),
            CMPhotoAdjustItem(id: .contrast, title: "对比度"),
            CMPhotoAdjustItem(id: .saturation, title: "饱和度"),
            CMPhotoAdjustItem(id: .white, title: "白平衡"),
            CMPhotoAdjustItem(id: .tone, title: "色调"),
            CMPhotoAdjustItem(id: .hsl, title: "HSL"),
            CMPhotoAdjustItem(id: .fade, title: "褪色"),
            CMPhotoAdjustItem(id: .highlights, title: "高光"),
            CMPhotoAdjustItem(id: .shadows, title: "阴影"),
            CMPhotoAdjustItem(id: .sharpen, title: "锐化"),
            CMPhotoAdjustItem(id: .vignette, title: "暗角"),
            CMPhotoAdjustItem(id: .blur, title: "模糊"),
            CMPhotoAdjustItem(id: .clarity, title: "清晰度")
        ]
    }
    
    static func defaultAdjustItem() -> CMPhotoAdjustItem {
        CMPhotoAdjustItem(id: .brightness, title: "亮度")
    }
}

extension CMPhotoAdjustItem {
    func createRulerView() -> CMRulerView {
        let ruler = CMRulerView()
        ruler.translatesAutoresizingMaskIntoConstraints = false
        ruler.backgroundColor = .clear
        
        switch id {
        case .brightness:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .contrast:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .saturation:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .white:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .tone:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .hsl:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .fade:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .highlights:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .shadows:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .sharpen:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .vignette:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .blur:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        case .clarity:
            ruler.configuration = CMRulerView.Configuration(
                minValue: -100,
                maxValue: 100,
                majorStep: 10,
                mediumStep: 5,
                valueChanged: { value in
                    
                },
                fadeEffectEnabled: false,    // 启用肉卷效果
                fadeDistance: 120,         // 120pt 外开始淡出
                minScale: 0.4,             // 最小缩放到 40%
                minAlpha: 0.1              // 最小透明度 20%
            )
        }
        
        return ruler
    }
}
