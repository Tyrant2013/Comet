import Foundation
import MetalKit
import CoreImage

class CMPhotoEditorMetalRenderer: NSObject {
    private let device: MTLDevice
    private var currentCIImage: CIImage?
    private let ciContext: CIContext
    
    init(device: MTLDevice) {
        self.device = device
        self.ciContext = CIContext(mtlDevice: device)
        
        super.init()
    }
    
    func update(image: CIImage) {
        currentCIImage = image
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let ciImage = currentCIImage else {
            return
        }
        
        let bounds = CGRect(origin: .zero, size: drawable.texture.width > 0 ? CGSize(width: drawable.texture.width, height: drawable.texture.height) : ciImage.extent.size)
        
        ciContext.render(ciImage,
                        to: drawable.texture,
                        commandBuffer: nil,
                        bounds: bounds,
                        colorSpace: CGColorSpaceCreateDeviceRGB())
        
        drawable.present()
    }
}
