//
//  CMCameraView.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import UIKit
import MetalKit
import AVFoundation
import SwiftUI

public class CMCameraView: UIView {
    let camera: CMCamera
    private let metalPreview: MTKView = .init(frame: .zero, device: CMMetalDevice.shared.device)
    private var currentTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    
    private var focusAnimatedView: CMCameraFocusAnimatedView = CMCameraFocusAnimatedView()
    
    public init(camera: CMCamera) {
        self.camera = camera
        super.init(frame: .zero)
        
        camera.cameraFrameDataHandler = cameraDataUpdate
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        camera = CMCamera()
        
        super.init(coder: coder)
        
        setupUI()
    }
    
    private func setupUI() {
        metalPreview.framebufferOnly = true
        metalPreview.delegate = self
        addSubview(metalPreview)
        
        addSubview(focusAnimatedView)
        
        addGestures()
        
        let vertexs: [Float] = [
            -1, -1, 0, 1, 1, 0,
            -1,  1, 0, 1, 0, 0,
             1, -1, 0, 1, 1, 1,
             1,  1, 0, 1, 0, 1
        ]
        vertexBuffer = CMMetalDevice.shared.device.makeBuffer(bytes: vertexs, length: vertexs.count * MemoryLayout<Float>.size, options: .storageModeShared)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        metalPreview.frame = bounds
    }
    
    private func addGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tagForFocus(_:)))
        addGestureRecognizer(tap)
        
        let pin = UIPinchGestureRecognizer(target: self, action: #selector(pinchForZoom(_:)))
        addGestureRecognizer(pin)
    }
    @objc
    private func tagForFocus(_ sender: UITapGestureRecognizer) {
        let size = bounds.size
        let point = sender.location(in: self)
        let focusPoint = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)
        
        focusAnimatedView.animateFocus(at: point)
        
        camera.setFocus(focusPoint)
    }
    
    private var beginZoomFactor: CGFloat = 1
    private var desiredZoomFactor: CGFloat = 1
    private var currentZoomFactor: CGFloat = 1
    private var isPinching: Bool = false
    @objc
    private func pinchForZoom(_ sender: UIPinchGestureRecognizer) {
        switch sender.state {
        case .began:
            isPinching = true
            
        case .changed:
            // 计算新的缩放值
            var desiredZoomFactor = beginZoomFactor * sender.scale
            
            // 限制缩放范围
            let minZoom: CGFloat = 1.0
            let maxZoom = 5.0
            desiredZoomFactor = min(max(desiredZoomFactor, minZoom), maxZoom)
            
        case .ended, .cancelled, .failed:
            isPinching = false
            beginZoomFactor = currentZoomFactor
            
            // 重置手势 scale，避免下次累积
            sender.scale = 1.0
            
        default:
            break
        }
        camera.setZoomFactor(desiredZoomFactor)
    }
}

extension CMCameraView: MTKViewDelegate {
    
    func cameraDataUpdate(_ sampleBuffer: CMSampleBuffer) {
        
        currentTexture = sampleBuffer.covertToMTLTexture(textureCache: CMMetalDevice.shared.metalTextureCache)
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    public func draw(in view: MTKView) {
        guard let texture = currentTexture else { return }
        
        guard let drawable = view.currentDrawable,
              let desc = view.currentRenderPassDescriptor
        else { return }
        
        guard let pipelineState = CMMetalPipelineState.shared.pipelineState
        else { return }
        
        CMMetalDevice.shared.commandQueue.enqueueVertexBuffer(
            vertexBuffer,
            texture: texture,
            drawable: drawable,
            pipelineState: pipelineState,
            renderPassDescriptor: desc
        )
    }
}

public struct CMCameraView_SwifUI: UIViewRepresentable {
    let camera: CMCamera
    public init(camera: CMCamera) {
        self.camera = camera
    }
    
    public func makeUIView(context: Context) -> CMCameraView {
        let view = CMCameraView(camera: camera)
        return view
    }
    
    public func updateUIView(_ uiView: CMCameraView, context: Context) {
        
    }
}
