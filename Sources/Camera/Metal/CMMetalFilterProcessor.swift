//
//  CMMetalFilterProcessor.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation
import MetalKit
import AVFoundation

final class CMMetalFilterProcessor {
    static let shared = CMMetalFilterProcessor(device: CMMetalDevice.shared.device)
    
    private static let maxFilterCount = 16
    
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let fullscreenVertexBuffer: MTLBuffer?
    
    init(device: MTLDevice) {
        self.device = device
        
        let vertices: [Float] = [
            -1, -1, 0, 1, 1, 0,
            -1,  1, 0, 1, 0, 0,
             1, -1, 0, 1, 1, 1,
             1,  1, 0, 1, 0, 1
        ]
        fullscreenVertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.size,
            options: .storageModeShared
        )
        
        let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
        let vertexFunc = library?.makeFunction(name: "vertexFunc")
        let fragmentFunc = library?.makeFunction(name: "filteredFragmentFunc")
        
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunc
        desc.fragmentFunction = fragmentFunc
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDesc = MTLVertexDescriptor()
        vertexDesc.attributes[0].format = .float4
        vertexDesc.attributes[0].bufferIndex = 0
        vertexDesc.attributes[0].offset = 0
        
        vertexDesc.attributes[1].format = .float2
        vertexDesc.attributes[1].bufferIndex = 0
        vertexDesc.attributes[1].offset = MemoryLayout<Float>.size * 4
        
        vertexDesc.layouts[0].stepFunction = .perVertex
        vertexDesc.layouts[0].stride = MemoryLayout<Float>.size * 6
        desc.vertexDescriptor = vertexDesc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        }
        catch {
            fatalError("Create filter pipeline state failed: \(error.localizedDescription)")
        }
    }
    
    func drawPreview(texture: MTLTexture,
                     filters: [CMCameraFilter],
                     vertexBuffer: MTLBuffer?,
                     drawable: CAMetalDrawable,
                     renderPassDescriptor: MTLRenderPassDescriptor,
                     commandQueue: MTLCommandQueue) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        
        let filterUniformData = makeFilterUniformData(filters: filters)
        filterUniformData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            encoder.setFragmentBytes(ptr, length: rawBuffer.count, index: 0)
        }
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func applyFilters(to pixelBuffer: CVPixelBuffer, filters: [CMCameraFilter]) -> CVPixelBuffer? {
        guard !filters.isEmpty else { return pixelBuffer }
        guard let textureCache = CMMetalDevice.shared.metalTextureCache else { return pixelBuffer }
        guard let commandBuffer = CMMetalDevice.shared.commandQueue.makeCommandBuffer() else { return pixelBuffer }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let inputTexture = pixelBuffer.covertToMTLTexture(textureCache: textureCache) else { return pixelBuffer }
        guard let outputPixelBuffer = makeOutputPixelBuffer(width: width, height: height) else { return pixelBuffer }
        guard let outputTexture = outputPixelBuffer.covertToMTLTexture(textureCache: textureCache) else { return pixelBuffer }
        
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = outputTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return pixelBuffer
        }
        
        guard let vertexBuffer = fullscreenVertexBuffer else { return pixelBuffer }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(inputTexture, index: 0)
        
        let filterUniformData = makeFilterUniformData(filters: filters)
        filterUniformData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            encoder.setFragmentBytes(ptr, length: rawBuffer.count, index: 0)
        }
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outputPixelBuffer
    }
    
    private struct FilterUniform {
        var type: UInt32
        var intensity: Float
        var param0: Float
        var param1: Float
    }
    
    private func makeFilterUniformData(filters: [CMCameraFilter]) -> Data {
        var data = Data()
        let maxCount = Self.maxFilterCount
        var count = UInt32(min(filters.count, maxCount))
        var padding0: UInt32 = 0
        var padding1: UInt32 = 0
        var padding2: UInt32 = 0
        
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding0) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding1) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding2) { data.append(contentsOf: $0) }
        
        for index in 0..<maxCount {
            let filter: FilterUniform
            if index < filters.count {
                let item = filters[index]
                filter = FilterUniform(
                    type: item.kind.rawValue,
                    intensity: item.intensity,
                    param0: item.param0,
                    param1: item.param1
                )
            }
            else {
                filter = FilterUniform(type: 0, intensity: 0, param0: 0, param1: 0)
            }
            var f = filter
            withUnsafeBytes(of: &f) { data.append(contentsOf: $0) }
        }
        return data
    }
    
    private func makeOutputPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
}
