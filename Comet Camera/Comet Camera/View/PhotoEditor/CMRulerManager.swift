//
//  CMRulerManager.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/4/6.
//

import Foundation
import UIKit

final class CMRulerManager {
    let items: [CMPhotoAdjustItem] = CMPhotoAdjustItem.supportedAdjustItems()
    
    private(set) var rulers: [CMPhotoAdjustType: CMRulerView] = [:]
    
    func getRulter(_ adjust: CMPhotoAdjustItem) -> CMRulerView {
        if let ruler = rulers[adjust.id] {
            return ruler
        }
        let newRuler = adjust.createRulerView()
        rulers[adjust.id] = newRuler
        return newRuler
    }
}
