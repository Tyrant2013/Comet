import Foundation
import CoreImage
import MetalKit
import CoreVideo

public final class CMPhotoEditorMetalFilterProcessor {
    public static let shared = CMPhotoEditorMetalFilterProcessor()

    private static let maxFilterCount = 16

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let textureCache: CVMetalTextureCache
    private let fullscreenVertexBuffer: MTLBuffer?
    private let ciContext: CIContext

    private struct FilterUniform {
        var type: UInt32
        var intensity: Float
        var param0: Float
        var param1: Float
    }

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        guard status == kCVReturnSuccess, let textureCache = cache else {
            return nil
        }
        self.textureCache = textureCache

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

        guard let library = CMPhotoEditorMetalFilterProcessor.makeLibrary(from: device) else {
            return nil
        }

        guard let vertexFunc = library.makeFunction(name: "vertexFunc"),
              let fragmentFunc = library.makeFunction(name: "filteredFragmentFunc") else {
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].offset = 0

        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4

        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 6
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            return nil
        }

        ciContext = CIContext(mtlDevice: device)
    }

    public func applyFilter(to image: CIImage, filterType: UInt32) -> CIImage? {
        guard filterType > 0 else { return image }

        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)

        guard width > 0, height > 0 else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let inputPixelBuffer = pixelBuffer else {
            return nil
        }

        ciContext.render(image, to: inputPixelBuffer)

        guard let inputTexture = createTexture(from: inputPixelBuffer),
              let outputPixelBuffer = createOutputPixelBuffer(width: width, height: height),
              let outputTexture = createTexture(from: outputPixelBuffer) else {
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = makeRenderPassDescriptor(outputTexture: outputTexture),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let vertexBuffer = fullscreenVertexBuffer else {
            return nil
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(inputTexture, index: 0)

        var filterUniformData = makeFilterUniformData(filterType: filterType)
        filterUniformData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            encoder.setFragmentBytes(ptr, length: rawBuffer.count, index: 0)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return CIImage(cvPixelBuffer: outputPixelBuffer).transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
    }

    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess, let cvTexture = cvTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(cvTexture)
    }

    private func createOutputPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferMetalCompatibilityKey: true
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

        return status == kCVReturnSuccess ? pixelBuffer : nil
    }

    private func makeRenderPassDescriptor(outputTexture: MTLTexture) -> MTLRenderPassDescriptor? {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = outputTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return descriptor
    }

    private func makeFilterUniformData(filterType: UInt32) -> Data {
        var data = Data()

        var count: UInt32 = 1
        var padding0: UInt32 = 0
        var padding1: UInt32 = 0
        var padding2: UInt32 = 0

        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding0) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding1) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &padding2) { data.append(contentsOf: $0) }

        let filter = FilterUniform(
            type: filterType,
            intensity: 1.0,
            param0: 0,
            param1: 0
        )

        var f = filter
        withUnsafeBytes(of: &f) { data.append(contentsOf: $0) }

        let maxCount = Self.maxFilterCount
        for _ in 1..<maxCount {
            let emptyFilter = FilterUniform(type: 0, intensity: 0, param0: 0, param1: 0)
            var ef = emptyFilter
            withUnsafeBytes(of: &ef) { data.append(contentsOf: $0) }
        }

        return data
    }

    private static func makeLibrary(from device: MTLDevice) -> MTLLibrary? {
        if let library = try? device.makeDefaultLibrary() {
            return library
        }
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
            return library
        }
        return nil
    }
}
