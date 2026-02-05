//
//  File.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/2/5.
//

import Foundation
import MetalKit

public extension MTLCommandQueue {
    func enqueueVertexBuffer(_ vertexBuffer: MTLBuffer?,
                             texture: MTLTexture,
                             drawable: CAMetalDrawable,
                             pipelineState: MTLRenderPipelineState,
                             renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let commandBuffer = makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }
        
        commandEncoder.setRenderPipelineState(pipelineState)
        
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentTexture(texture, index: 0)
        
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
