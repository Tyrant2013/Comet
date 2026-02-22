import Foundation
import MetalKit
import CoreImage
import Accelerate

class CMPhotoEditorMetalRenderer: NSObject {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var currentTexture: MTLTexture?
    private var currentImageAspectRatio: Float = 1.0
    private let vertexBuffer: MTLBuffer
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private let ciContext: CIContext
    var contentMode: CMPhotoEditorContentMode = .scaleAspectFit
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.ciContext = CIContext()
        
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
        )!
        
        pipelineState = Self.makePipelineState(device: device)
        
        super.init()
        
        setupTextureCache()
    }
    
    private func setupTextureCache() {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = try? device.makeDefaultLibrary(bundle: Bundle.module)
        let vertexFunc = library?.makeFunction(name: "vertexFunc")
        let fragmentFunc = library?.makeFunction(name: "fragmentFunc")
        
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
            return try device.makeRenderPipelineState(descriptor: desc)
        }
        catch {
            fatalError("Create pipeline state failed: \(error.localizedDescription)")
        }
    }
    
    func update(image: CIImage?) {
        guard let image = image else {
            currentTexture = nil
            currentImageAspectRatio = 1.0
            return
        }
        
        currentTexture = image.convertToMTLTexture(textureCache: textureCache, ciContext: ciContext)
        currentImageAspectRatio = Float(image.extent.width / image.extent.height)
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let texture = currentTexture else {
            return
        }
        
        let viewAspectRatio = Float(drawable.texture.width) / Float(drawable.texture.height)
        let texCoords = calculateTexCoords(imageAspectRatio: currentImageAspectRatio, viewAspectRatio: viewAspectRatio, contentMode: contentMode)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        let vertices = makeVertices(texCoords: texCoords)
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: .storageModeShared)
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func calculateTexCoords(imageAspectRatio: Float, viewAspectRatio: Float, contentMode: CMPhotoEditorContentMode) -> (minX: Float, minY: Float, maxX: Float, maxY: Float) {
        switch contentMode {
        case .scaleAspectFit:
            return calculateScaledToFitTexCoords(imageAspectRatio: imageAspectRatio, viewAspectRatio: viewAspectRatio)
        case .scaleAspectFill:
            return calculateScaledToFillTexCoords(imageAspectRatio: imageAspectRatio, viewAspectRatio: viewAspectRatio)
        }
    }
    
    private func calculateScaledToFitTexCoords(imageAspectRatio: Float, viewAspectRatio: Float) -> (minX: Float, minY: Float, maxX: Float, maxY: Float) {
        if imageAspectRatio > viewAspectRatio {
            let texHeight = 1.0 / imageAspectRatio * viewAspectRatio
            let offset = (1.0 - texHeight) / 2.0
            return (minX: 0, minY: offset, maxX: 1, maxY: 1.0 - offset)
        } else {
            let texWidth = imageAspectRatio / viewAspectRatio
            let offset = (1.0 - texWidth) / 2.0
            return (minX: offset, minY: 0, maxX: 1.0 - offset, maxY: 1)
        }
    }
    
    private func calculateScaledToFillTexCoords(imageAspectRatio: Float, viewAspectRatio: Float) -> (minX: Float, minY: Float, maxX: Float, maxY: Float) {
        if imageAspectRatio > viewAspectRatio {
            let texWidth = imageAspectRatio / viewAspectRatio
            let offset = (texWidth - 1.0) / 2.0
            return (minX: -offset, minY: 0, maxX: 1.0 + offset, maxY: 1)
        } else {
            let texHeight = 1.0 / imageAspectRatio * viewAspectRatio
            let offset = (texHeight - 1.0) / 2.0
            return (minX: 0, minY: -offset, maxX: 1, maxY: 1.0 + offset)
        }
    }
    
    private func makeVertices(texCoords: (minX: Float, minY: Float, maxX: Float, maxY: Float)) -> [Float] {
        return [
            -1, -1, 0, 1, texCoords.minX, texCoords.maxY,
            -1,  1, 0, 1, texCoords.minX, texCoords.minY,
             1, -1, 0, 1, texCoords.maxX, texCoords.maxY,
             1,  1, 0, 1, texCoords.maxX, texCoords.minY
        ]
    }
}

extension CIImage {
    func convertToMTLTexture(textureCache: CVMetalTextureCache?, ciContext: CIContext) -> MTLTexture? {
        let extent = extent.integral
        let width = Int(extent.width)
        let height = Int(extent.height)
        
        guard width > 0, height > 0, let textureCache = textureCache else { return nil }
        
        let pixelBuffer = createPixelBuffer(width: width, height: height, ciContext: ciContext)
        guard let pixelBuffer = pixelBuffer else { return nil }
        
        var textureRef: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &textureRef
        )
        
        guard status == kCVReturnSuccess,
              let textureRef = textureRef,
              let texture = CVMetalTextureGetTexture(textureRef) else {
            return nil
        }
        
        return texture
    }
    
    private func createPixelBuffer(width: Int, height: Int, ciContext: CIContext) -> CVPixelBuffer? {
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
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else { return nil }
        
        ciContext.render(self, to: pixelBuffer)
        return pixelBuffer
    }
}
