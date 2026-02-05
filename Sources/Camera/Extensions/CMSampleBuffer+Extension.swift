//
//  File.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/2/5.
//

import Foundation
import AVFoundation
import MetalKit

public extension CMSampleBuffer {
    func covertToMTLTexture(textureCache: CVMetalTextureCache?) -> MTLTexture? {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        guard let textureCache else { return nil }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        
        var metalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, .bgra8Unorm, width, height, 0, &metalTexture)
        
        guard let metalTexture else { return nil }
        
        return CVMetalTextureGetTexture(metalTexture)
        
    }
}
