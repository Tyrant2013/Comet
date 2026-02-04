//
//  CMPhotoCaptureSettings.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import AVFoundation

public struct CMPhotoCaptureSettings: Sendable {
    var flashMode: AVCaptureDevice.FlashMode = .auto
    var torchMode: AVCaptureDevice.TorchMode = .auto
}

extension CMPhotoCaptureSettings {
    static let `default` = CMPhotoCaptureSettings()
}
