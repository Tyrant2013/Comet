//
//  CMPhotoCaptureSettings.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import AVFoundation

public struct CMPhotoCaptureSettings: Sendable {
    public var flashMode: AVCaptureDevice.FlashMode
    public var torchMode: AVCaptureDevice.TorchMode
    
    public init(
        flashMode: AVCaptureDevice.FlashMode = .auto,
        torchMode: AVCaptureDevice.TorchMode = .auto
    ) {
        self.flashMode = flashMode
        self.torchMode = torchMode
    }
}

public extension CMPhotoCaptureSettings {
    static let `default` = CMPhotoCaptureSettings()
}
