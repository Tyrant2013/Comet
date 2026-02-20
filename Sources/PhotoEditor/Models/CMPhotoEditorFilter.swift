import Foundation

public enum CMPhotoEditorFilter: Sendable {
    case none
    case noir
    case chrome
    case mono
    case instant

    var coreImageName: String? {
        switch self {
        case .none:
            nil
        case .noir:
            "CIPhotoEffectNoir"
        case .chrome:
            "CIPhotoEffectChrome"
        case .mono:
            "CIPhotoEffectMono"
        case .instant:
            "CIPhotoEffectInstant"
        }
    }

    var metalFilterType: UInt32 {
        switch self {
        case .none:
            0
        case .noir:
            3
        case .chrome:
            4
        case .mono:
            1
        case .instant:
            5
        }
    }
}
