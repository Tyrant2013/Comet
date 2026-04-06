//
//  CMRulerManager.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/4/6.
//

import Foundation
import UIKit

final class CMRulerManager {
    let items: [CMPhotoAdjustItem] = [
        CMPhotoAdjustItem(id: 1,  title: "曝光"),
        CMPhotoAdjustItem(id: 2,  title: "鲜明度"),
        CMPhotoAdjustItem(id: 3,  title: "高光"),
//        CMPhotoAdjustItem(id: 4,  title: "阴影"),
        CMPhotoAdjustItem(id: 5,  title: "对比度"),
        CMPhotoAdjustItem(id: 6,  title: "亮度"),
//        CMPhotoAdjustItem(id: 7,  title: "黑点"),
        CMPhotoAdjustItem(id: 8,  title: "饱和度"),
//        CMPhotoAdjustItem(id: 9,  title: "自然饱和度"),
        CMPhotoAdjustItem(id: 10, title: "色温"),
        CMPhotoAdjustItem(id: 11, title: "色调"),
        CMPhotoAdjustItem(id: 12, title: "锐度"),
//        CMPhotoAdjustItem(id: 13, title: "清晰度"),
//        CMPhotoAdjustItem(id: 14, title: "噪点消除"),
//        CMPhotoAdjustItem(id: 15, title: "晕影")
    ]
    
    private(set) var rulers: [Int: CMRulerView] = [:]
    
    init() {
        initRulerViews()
    }
    
    private func initRulerViews() {
        // 曝光
        let exposureRuler = CMRulerView()
        exposureRuler.translatesAutoresizingMaskIntoConstraints = false
        exposureRuler.backgroundColor = .clear
        exposureRuler.configuration = CMRulerView.Configuration(
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
        rulers[1] = exposureRuler
        // 鲜明度
        let vibranceRuler = CMRulerView()
        vibranceRuler.translatesAutoresizingMaskIntoConstraints = false
        vibranceRuler.backgroundColor = .clear
        vibranceRuler.configuration = CMRulerView.Configuration(
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
        rulers[2] = vibranceRuler
        // 高光
        let highlightsRuler = CMRulerView()
        highlightsRuler.translatesAutoresizingMaskIntoConstraints = false
        highlightsRuler.backgroundColor = .clear
        highlightsRuler.configuration = CMRulerView.Configuration(
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
        rulers[3] = highlightsRuler
        // 对比度
        let contrastRuler = CMRulerView()
        contrastRuler.translatesAutoresizingMaskIntoConstraints = false
        contrastRuler.backgroundColor = .clear
        contrastRuler.configuration = CMRulerView.Configuration(
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
        rulers[4] = contrastRuler
        
        // 亮度
        let brightnessRuler = CMRulerView()
        brightnessRuler.translatesAutoresizingMaskIntoConstraints = false
        brightnessRuler.backgroundColor = .clear
        brightnessRuler.configuration = CMRulerView.Configuration(
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
        rulers[6] = brightnessRuler
        
        // 饱和度
        let saturationRuler = CMRulerView()
        saturationRuler.translatesAutoresizingMaskIntoConstraints = false
        saturationRuler.backgroundColor = .clear
        saturationRuler.configuration = CMRulerView.Configuration(
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
        rulers[8] = saturationRuler
        // 色温
        let temperatureRuler = CMRulerView()
        temperatureRuler.translatesAutoresizingMaskIntoConstraints = false
        temperatureRuler.backgroundColor = .clear
        temperatureRuler.configuration = CMRulerView.Configuration(
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
        rulers[10] = temperatureRuler
        // 色调
        let hueRuler = CMRulerView()
        hueRuler.translatesAutoresizingMaskIntoConstraints = false
        hueRuler.backgroundColor = .clear
        hueRuler.configuration = CMRulerView.Configuration(
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
        rulers[11] = hueRuler
        
        // 锐度
        let sharpnessRuler = CMRulerView()
        sharpnessRuler.translatesAutoresizingMaskIntoConstraints = false
        sharpnessRuler.backgroundColor = .clear
        sharpnessRuler.configuration = CMRulerView.Configuration(
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
        rulers[12] = sharpnessRuler
    }
    
    func getRulter(_ adjust: CMPhotoAdjustItem) -> CMRulerView? {
        if let ruler = rulers[adjust.id] {
            return ruler
        }
        return nil
    }
}
