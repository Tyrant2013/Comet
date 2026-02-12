//
//  CMPhotoEditor.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation
import AVFoundation

public enum CMPhotoEditor {
    public static func apply(filters: [CMCameraFilter], to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        CMMetalFilterProcessor.shared.applyFilters(to: pixelBuffer, filters: filters) ?? pixelBuffer
    }
    
    public static func apply(filters: [CMCameraFilter], to photo: CMPhoto) -> CMPhoto {
        let processed = apply(filters: filters, to: photo.pixelBuffer)
        return CMPhoto(pixelBuffer: processed)
    }
}
