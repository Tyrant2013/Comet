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
}
