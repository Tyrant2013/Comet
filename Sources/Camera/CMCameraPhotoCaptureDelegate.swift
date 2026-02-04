//
//  CMCameraPhotoCaptureDelegate.swift
//  CameraExample
//  拍照回调
//  Created by zhuangxiaowei on 2026/2/4.
//

import UIKit
import AVFoundation

class CMCameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let id: UUID = UUID()
    var completionHandler: (UUID, CVPixelBuffer?, Error?) -> Void
    
    init(completionHandler: @escaping (UUID, CVPixelBuffer?, Error?) -> Void) {
        self.completionHandler = completionHandler
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: (any Error)?) {
        
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        if error != nil {
            completionHandler(id, nil, error)
        }
        
        guard let pixelBuffer = photo.pixelBuffer else { return }
        completionHandler(id, pixelBuffer, nil)
    }
}
