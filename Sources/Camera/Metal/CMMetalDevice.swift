//
//  CMMetalDevice.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import MetalKit

class CMMetalDevice: @unchecked Sendable {
    static let shared = CMMetalDevice()
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var metalTextureCache: CVMetalTextureCache?
    init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else { fatalError("") }
        device = defaultDevice
        
        guard let queue = device.makeCommandQueue() else { fatalError("") }
        commandQueue = queue
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &metalTextureCache)
    }
}
