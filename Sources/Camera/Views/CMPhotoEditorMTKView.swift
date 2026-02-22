import Foundation
import UIKit
import MetalKit
import CoreImage

public enum CMPhotoEditorContentMode {
    case scaleAspectFit
    case scaleAspectFill
}

public class CMPhotoEditorMTKView: UIView {
    private let metalView: MTKView
    private let renderer: CMPhotoEditorMetalRenderer
    
    public var image: CIImage? {
        didSet {
            renderer.update(image: image ?? CIImage())
            metalView.setNeedsDisplay()
        }
    }
    
    public var imageContentMode: CMPhotoEditorContentMode = .scaleAspectFit {
        didSet {
            renderer.contentMode = imageContentMode
            metalView.setNeedsDisplay()
        }
    }
    
    public override init(frame: CGRect) {
        let device = CMMetalDevice.shared.device
        metalView = MTKView(frame: .zero, device: device)
        renderer = CMPhotoEditorMetalRenderer(device: device)
        
        super.init(frame: frame)
        
        setupView()
    }
    
    public required init?(coder: NSCoder) {
        let device = CMMetalDevice.shared.device
        metalView = MTKView(frame: .zero, device: device)
        renderer = CMPhotoEditorMetalRenderer(device: device)
        
        super.init(coder: coder)
        
        setupView()
    }
    
    private func setupView() {
        metalView.framebufferOnly = false
        metalView.delegate = self
        metalView.backgroundColor = .black
        metalView.contentMode = .scaleAspectFit
        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        
        addSubview(metalView)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.frame = bounds
    }
}

extension CMPhotoEditorMTKView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in view: MTKView) {
        renderer.draw(in: view)
    }
}
