//
//  CCLensController.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import Foundation
import Combine

class CCLensControl: ObservableObject {
    @Published var currentLens: CCLens
    let visibleLens: [CCLens] = [
        CCLens(id: ".5"),
        CCLens(id: "1"),
        CCLens(id: "2")
    ]
    
    init() {
        self.currentLens = visibleLens[1]
    }
    
    func change(to: CCLens) {
        currentLens = to
    }
}
