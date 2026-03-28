//
//  UIImage+Icon.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/3/28.
//

import Foundation
import UIKit

extension UIImage {
    static var doneImage: UIImage? {
        return UIImage(systemName: "checkmark",
                       withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
    }
    
    static var cancelImage: UIImage? {
        return UIImage(systemName: "xmark",
                       withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
    }
    
    static var rotateCCWImage: UIImage? {
        return UIImage(systemName: "rotate.left.fill",
                       withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 4)
    }
    
    static var rotateCWImage: UIImage? {
        guard let ccw = rotateCCWImage, let cg = ccw.cgImage else { return nil }
        let renderer = UIGraphicsImageRenderer(size: ccw.size)
        return renderer.image { context in
            let cgctx = context.cgContext
            cgctx.translateBy(x: ccw.size.width, y: ccw.size.height)
            cgctx.rotate(by: .pi)
            cgctx.draw(cg, in: CGRect(origin: .zero, size: ccw.size))
        }
    }
    
    static var resetImage: UIImage? {
        return UIImage(systemName: "arrow.counterclockwise",
                       withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 0)
    }
    
    static var clampImage: UIImage? {
        return UIImage(systemName: "aspectratio.fill",
                       withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 0)
    }
}
