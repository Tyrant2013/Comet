//
//  CMCamera.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import UIKit
import AVFoundation

public class CMCamera: NSObject, @unchecked Sendable, ObservableObject {
    let session: AVCaptureSession = AVCaptureSession()
    
    private let cameraDataQueue = DispatchQueue(label: "camera.data.queue")
    private var photoCaptureHandlers: [UUID: CMCameraPhotoCaptureDelegate] = [:]
    
    var cameraFrameDataHandler: ((CMSampleBuffer) -> Void)?
    
    @Published var photoCaptureSettings: CMPhotoCaptureSettings = .default
    
    public override init() {
        super.init()
        do {
            try setupSession()
        }
        catch {
            switch error {
            case CMCameraError.inputFailed(let msg):
                print(msg)
            default:
                print(error.localizedDescription)
            }
        }
    }
    /// 启动Session
    func start() {
        guard !session.isRunning else { return }
        cameraDataQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }
    /// 停止Session
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
    
    /// 拍照
    func takePhoto() async -> CMPhoto? {
        guard let photoOutput = session.outputs.first(where: { $0 is AVCapturePhotoOutput }) as? AVCapturePhotoOutput else { return nil }
        
        let setting = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        setting.flashMode = photoCaptureSettings.flashMode
        setting.photoQualityPrioritization = .quality
        
        return await withCheckedContinuation { checkedContinuation in
            let photoCaptureDelegate = CMCameraPhotoCaptureDelegate { [weak self] id, sampleBuffer, error in
                let strongSelf = self
                strongSelf?.photoCaptureHandlers.removeValue(forKey: id)
                
                if let pixelBuffer = sampleBuffer {
                    let photo = CMPhoto(pixelBuffer: pixelBuffer)
                    checkedContinuation.resume(returning: photo)
                }
                else {
                    checkedContinuation.resume(returning: nil)
                }
            }
            photoCaptureHandlers[photoCaptureDelegate.id] = photoCaptureDelegate
            photoOutput.capturePhoto(with: setting, delegate: photoCaptureDelegate)
        }
    }
    
    private func setupSession() throws {
        try addInput()
        
        addOutput()
        
    }
    
    private func addInput() throws {
        guard let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
        else { throw CMCameraError.deviceUnavailable }
        do {
            session.beginConfiguration()
            let cameraInput = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            }
            session.commitConfiguration()
        }
        catch {
            throw CMCameraError.inputFailed(error.localizedDescription)
        }
    }
    
    private func addOutput() {
        session.beginConfiguration()
        let cameraOutput = AVCaptureVideoDataOutput()
        cameraOutput.setSampleBufferDelegate(self, queue: cameraDataQueue)
        cameraOutput.alwaysDiscardsLateVideoFrames = true
        cameraOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(cameraOutput) {
            session.addOutput(cameraOutput)
        }
        
        if let connection = cameraOutput.connection(with: .video) {
            if #available(iOS 17, *) {
                if connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
                
            }
            else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
        session.commitConfiguration()
    }
    
    private func addPhotoCaptureOutput() {
        session.beginConfiguration()
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }
    
}

extension CMCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        cameraFrameDataHandler?(sampleBuffer)
    }
}
