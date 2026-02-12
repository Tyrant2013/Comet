//
//  CMCameraFilter.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation

public enum CMCameraFilterKind: UInt32, CaseIterable, Sendable {
    case monochrome = 1
    case polaroid = 2
}

public struct CMCameraFilter: Equatable, Sendable {
    public var kind: CMCameraFilterKind
    public var intensity: Float
    public var param0: Float
    public var param1: Float
    
    public init(kind: CMCameraFilterKind, intensity: Float = 1.0, param0: Float = 0, param1: Float = 0) {
        self.kind = kind
        self.intensity = min(max(intensity, 0), 1)
        self.param0 = param0
        self.param1 = param1
    }
    
    public static func monochrome(intensity: Float = 1.0) -> CMCameraFilter {
        CMCameraFilter(kind: .monochrome, intensity: intensity)
    }
    
    public static func polaroid(intensity: Float = 1.0, warmth: Float = 0.18, fade: Float = 0.08) -> CMCameraFilter {
        CMCameraFilter(kind: .polaroid, intensity: intensity, param0: warmth, param1: fade)
    }
}
