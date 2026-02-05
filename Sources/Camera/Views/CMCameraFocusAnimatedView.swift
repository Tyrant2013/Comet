//
//  CMCameraFocusAnimatedView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/2/5.
//

import UIKit

class CMCameraFocusAnimatedView: UIView {
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        self.layer.borderColor = UIColor.yellow.cgColor
        self.layer.borderWidth = 2.0
        self.backgroundColor = .clear
        self.alpha = 0
    }
    
    func animateFocus(at point: CGPoint) {
        self.center = point
        self.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        self.alpha = 1.0
        
        UIView.animate(withDuration: 0.4, animations: {
            self.transform = CGAffineTransform.identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseOut, animations: {
                self.alpha = 0
            })
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

