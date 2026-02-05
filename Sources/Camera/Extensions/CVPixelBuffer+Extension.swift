//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/2/5.
//

import Foundation
import AVFoundation

public extension CVPixelBuffer {
    func covertToMTLTexture(textureCache: CVMetalTextureCache?) -> MTLTexture? {
        
        let imageBuffer = self
        guard let textureCache else { return nil }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        
        var metalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, .bgra8Unorm, width, height, 0, &metalTexture)
        
        guard let metalTexture else { return nil }
        
        return CVMetalTextureGetTexture(metalTexture)
        
    }
}
