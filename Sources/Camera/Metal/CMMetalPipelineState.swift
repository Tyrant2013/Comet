//
//  CMMetalPipelineState.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import MetalKit

class CMMetalPipelineState: @unchecked Sendable {
    static let shared = CMMetalPipelineState(device: CMMetalDevice.shared.device)
    
    private(set) var pipelineState: MTLRenderPipelineState?
    
    init(device: MTLDevice) {
        let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
        let vertexFunc = library?.makeFunction(name: "vertexFunc")
        let fragmentFunc = library?.makeFunction(name: "fragmentFunc")
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDesc = MTLVertexDescriptor()
        vertexDesc.attributes[0].format = .float4
        vertexDesc.attributes[0].bufferIndex = 0
        vertexDesc.attributes[0].offset = 0
        
        vertexDesc.attributes[1].format = .float2
        vertexDesc.attributes[1].bufferIndex = 0
        vertexDesc.attributes[1].offset = MemoryLayout<Float>.size * 4
        
        vertexDesc.layouts[0].stepFunction = .perVertex
        vertexDesc.layouts[0].stride = MemoryLayout<Float>.size * 6
        
        pipelineDesc.vertexDescriptor = vertexDesc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        }
        catch {
            fatalError("Create PipelineState failed: \(error.localizedDescription)")
        }
    }
}
