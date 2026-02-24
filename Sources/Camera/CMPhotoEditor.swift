//
//  CMPhotoEditor.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation
import AVFoundation
import CoreImage
import PhotoEditor

public enum CMPhotoEditor {
    public static func apply(filters: [CMCameraFilter], to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        CMMetalFilterProcessor.shared.applyFilters(to: pixelBuffer, filters: filters) ?? pixelBuffer
    }

    public static func apply(filters: [CMCameraFilter], to photo: CMPhoto) -> CMPhoto {
        let processed = apply(filters: filters, to: photo.pixelBuffer)
        return CMPhoto(pixelBuffer: processed)
    }

    public static func apply(operations: [CMPhotoEditOperation], to pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let input = CMPhotoEditorPixelBufferBridge.makeCIImage(from: pixelBuffer)
        let output = try PhotoEditor.CMPhotoEditor.edit(input, operations: operations)
        return CMPhotoEditorPixelBufferBridge.makePixelBuffer(from: output) ?? pixelBuffer
    }

    public static func apply(operations: [CMPhotoEditOperation], to photo: CMPhoto) throws -> CMPhoto {
        CMPhoto(pixelBuffer: try apply(operations: operations, to: photo.pixelBuffer))
    }
}
