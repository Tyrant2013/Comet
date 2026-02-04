//
//  CMCameraError.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import Foundation

public enum CMCameraError: Error {
    case deviceUnavailable
    case inputFailed(_ message: String)
}

