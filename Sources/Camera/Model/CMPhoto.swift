//
//  CMPhoto.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import AVFoundation

public struct CMPhoto: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    
    public init(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}
