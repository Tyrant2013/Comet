//
//  CMMetalRenderer.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import MetalKit
import AVFoundation

class CMMetalRenderer: NSObject {
    private let textureQueue = DispatchQueue(label: "camera.metal.texture.queue")
    private var currentTexture: MTLTexture?
    private let vertexBuffer: MTLBuffer?
    
    init(device: MTLDevice) {
        let vertices: [Float] = [
            -1, -1, 0, 1, 1, 0,
            -1,  1, 0, 1, 0, 0,
             1, -1, 0, 1, 1, 1,
             1,  1, 0, 1, 0, 1
        ]
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        )
    }
    
    func update(sampleBuffer: CMSampleBuffer, textureCache: CVMetalTextureCache?) {
        let texture = sampleBuffer.covertToMTLTexture(textureCache: textureCache)
        textureQueue.async { [weak self] in
            self?.currentTexture = texture
        }
    }
    
    func draw(in view: MTKView, pipelineState: MTLRenderPipelineState, commandQueue: MTLCommandQueue) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor
        else { return }
        
        let texture = textureQueue.sync { currentTexture }
        guard let texture else { return }
        
        commandQueue.enqueueVertexBuffer(
            vertexBuffer,
            texture: texture,
            drawable: drawable,
            pipelineState: pipelineState,
            renderPassDescriptor: descriptor
        )
    }
}
