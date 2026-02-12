//
//  CMLensType.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation

public enum LensType: CaseIterable, Equatable, Sendable {
    case ultraWide
    case wide
    case telephoto
    
    public var displayName: String {
        switch self {
        case .ultraWide:
            return "0.5x"
        case .wide:
            return "1x"
        case .telephoto:
            return "2x"
        }
    }
    
    public var statusName: String {
        switch self {
        case .ultraWide:
            return "超广角"
        case .wide:
            return "广角"
        case .telephoto:
            return "长焦"
        }
    }
}
