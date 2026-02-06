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
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchPoint = touches.first else { return }
        let size = bounds.size
        let point = touchPoint.location(in: self)
        let focusPoint = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)
        
        focusAnimatedView.animateFocus(at: point)
        
        camera.setFocus(focusPoint)
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
