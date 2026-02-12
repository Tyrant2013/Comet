//
//  CMCameraError.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation
import AVFoundation

public enum CMCameraError: Error {
    case deviceUnavailable
    case inputFailed(_ message: String)
    case cameraUnavailable(position: AVCaptureDevice.Position)
    case lensUnavailable(_ lens: LensType)
    case permissionDenied(_ message: String)
    case configurationFailed(_ message: String)
}

extension CMCameraError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "无法访问摄像头设备。"
        case .inputFailed(let message):
            return "创建摄像头输入失败：\(message)"
        case .cameraUnavailable(let position):
            switch position {
            case .front:
                return "当前设备不支持前置摄像头。"
            case .back:
                return "当前设备不支持后置摄像头。"
            default:
                return "当前设备不支持所选摄像头。"
            }
        case .lensUnavailable(let lens):
            return "当前设备不支持\(lens.statusName)。"
        case .permissionDenied(let message):
            return message
        case .configurationFailed(let message):
            return "相机会话配置失败：\(message)"
        }
    }
}
