//
//  UIImage+Icons.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/3/28.
//

import Foundation
import UIKit

extension UIImage {
    static func checkmark() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 17, height: 14))
        return renderer.image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 1, y: 7))
            path.addLine(to: CGPoint(x: 6, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 1))
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }
    
    static func xmark() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { _ in
            let p1 = UIBezierPath()
            p1.move(to: CGPoint(x: 15, y: 15))
            p1.addLine(to: CGPoint(x: 1, y: 1))
            UIColor.white.setStroke()
            p1.lineWidth = 2
            p1.stroke()
            
            let p2 = UIBezierPath()
            p2.move(to: CGPoint(x: 1, y: 15))
            p2.addLine(to: CGPoint(x: 15, y: 1))
            UIColor.white.setStroke()
            p2.lineWidth = 2
            p2.stroke()
        }
    }
    
    static func rotateLeftFill() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 21))
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 9, width: 12, height: 12)).fill()
            
            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: 5, y: 3))
            tri.addLine(to: CGPoint(x: 10, y: 6))
            tri.addLine(to: CGPoint(x: 10, y: 0))
            tri.close()
            tri.fill()
            
            let arc = UIBezierPath()
            arc.move(to: CGPoint(x: 10, y: 3))
            arc.addCurve(to: CGPoint(x: 17.5, y: 11),
                         controlPoint1: CGPoint(x: 15, y: 3),
                         controlPoint2: CGPoint(x: 17.5, y: 5.91))
            arc.lineWidth = 1
            arc.stroke()
        }
    }
    
    static func arrowCounterclockwise() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 22, height: 18))
        return renderer.image { _ in
            UIColor.white.setFill()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 22, y: 9))
            p.addCurve(to: CGPoint(x: 13, y: 18), controlPoint1: CGPoint(x: 22, y: 13.97), controlPoint2: CGPoint(x: 17.97, y: 18))
            p.addCurve(to: CGPoint(x: 13, y: 16), controlPoint1: CGPoint(x: 13, y: 17.35), controlPoint2: CGPoint(x: 13, y: 16.68))
            p.addCurve(to: CGPoint(x: 20, y: 9), controlPoint1: CGPoint(x: 16.87, y: 16), controlPoint2: CGPoint(x: 20, y: 12.87))
            p.addCurve(to: CGPoint(x: 13, y: 2), controlPoint1: CGPoint(x: 20, y: 5.13), controlPoint2: CGPoint(x: 16.87, y: 2))
            p.addCurve(to: CGPoint(x: 6.55, y: 6.27), controlPoint1: CGPoint(x: 10.1, y: 2), controlPoint2: CGPoint(x: 7.62, y: 3.76))
            p.addCurve(to: CGPoint(x: 6, y: 9), controlPoint1: CGPoint(x: 6.2, y: 7.11), controlPoint2: CGPoint(x: 6, y: 8.03))
            p.addLine(to: CGPoint(x: 4, y: 9))
            p.addCurve(to: CGPoint(x: 4.65, y: 5.63), controlPoint1: CGPoint(x: 4, y: 7.81), controlPoint2: CGPoint(x: 4.23, y: 6.67))
            p.addCurve(to: CGPoint(x: 7.65, y: 1.76), controlPoint1: CGPoint(x: 5.28, y: 4.08), controlPoint2: CGPoint(x: 6.32, y: 2.74))
            p.addCurve(to: CGPoint(x: 13, y: 0), controlPoint1: CGPoint(x: 9.15, y: 0.65), controlPoint2: CGPoint(x: 11, y: 0))
            p.addCurve(to: CGPoint(x: 22, y: 9), controlPoint1: CGPoint(x: 17.97, y: 0), controlPoint2: CGPoint(x: 22, y: 4.03))
            p.close()
            p.fill()
            
            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: 5, y: 15))
            tri.addLine(to: CGPoint(x: 10, y: 9))
            tri.addLine(to: CGPoint(x: 0, y: 9))
            tri.close()
            tri.fill()
        }
    }
    
    static func aspectratioFill() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 22, height: 16))
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 3, width: 13, height: 13)).fill()
            UIColor(white: 1.0, alpha: 0.553).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 22, height: 2)).fill()
            UIBezierPath(rect: CGRect(x: 19, y: 2, width: 3, height: 14)).fill()
            UIColor(white: 1.0, alpha: 0.773).setFill()
            UIBezierPath(rect: CGRect(x: 14, y: 3, width: 4, height: 13)).fill()
        }
    }
}
