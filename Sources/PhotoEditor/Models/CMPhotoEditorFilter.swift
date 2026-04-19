import Foundation

public enum CMPhotoEditorFilterType: String, CaseIterable, Hashable {
    case normal
    case blackAndWhite
    case sepia
    case vintage
    case chrome
    case fade
    case instant
    case process
    case transfer
    case curve
    case tonal
    case mono
}

public struct CMPhotoEditorFilter: Sendable, Hashable {
    let type: CMPhotoEditorFilterType
    let intensity: CGFloat
    
    public init(type: CMPhotoEditorFilterType, intensity: CGFloat = 1.0) {
        self.type = type
        self.intensity = intensity
    }
    
    var coreImageName: String? {
        switch type {
        case .normal:
            "CIColorControls"
        case .blackAndWhite:
            "CIColorMonochrome"
        case .sepia:
            "CISepiaTone"
        case .vintage:
            "CIPhotoEffectProcess"
        case .chrome:
            "CIPhotoEffectChrome"
        case .fade:
            "CIPhotoEffectFade"
        case .instant:
            "CIPhotoEffectInstant"
        case .process:
            "CIPhotoEffectProcess"
        case .transfer:
            "CIPhotoEffectTransfer"
        case .curve:
            "CIColorCurves"
        case .tonal:
            "CIPhotoEffectTonal"
        case .mono:
            "CIColorMonochrome"
        }
    }
    
    var metalFilterType: UInt32 {
        switch type {
        case .normal:
            0
        case .blackAndWhite:
            1
        case .sepia:
            2
        case .vintage:
            6
        case .chrome:
            4
        case .fade:
            7
        case .instant:
            5
        case .process:
            6
        case .transfer:
            8
        case .curve:
            9
        case .tonal:
            10
        case .mono:
            1
        }
    }
}

extension CMPhotoEditorFilter {
    public static func allFilters() -> [CMPhotoEditorFilter] {
        return CMPhotoEditorFilterType.allCases.map { type in
            CMPhotoEditorFilter(type: type, intensity: 1.0)
        }
    }
}
