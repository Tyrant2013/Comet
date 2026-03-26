import Foundation
import UIKit

@objcMembers
public final class CMCropViewControllerAspectRatioPreset: NSObject {
    public private(set) var size: CGSize
    public private(set) var title: String

    public init(size: CGSize, title: String) {
        self.size = size
        self.title = title
        super.init()
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CMCropViewControllerAspectRatioPreset else { return false }
        return CGSizeEqualToSize(size, other.size) && title == other.title
    }

    public static func portraitPresets() -> [CMCropViewControllerAspectRatioPreset] {
        let object = CMCropViewControllerAspectRatioPreset(size: .zero, title: "Original")
        let resourceBundle = CM_CROP_VIEW_RESOURCE_BUNDLE_FOR_OBJECT(object)
        return [
            CMCropViewControllerAspectRatioPreset(size: .zero,
                                                  title: NSLocalizedString("Original", tableName: "TOCropViewControllerLocalizable", bundle: resourceBundle, value: "Original", comment: "")),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 1.0, height: 1.0),
                                                  title: NSLocalizedString("Square", tableName: "TOCropViewControllerLocalizable", bundle: resourceBundle, value: "Square", comment: "")),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 2.0, height: 3.0), title: "2:3"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 3.0, height: 5.0), title: "3:5"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 3.0, height: 4.0), title: "3:4"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 4.0, height: 5.0), title: "4:5"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 5.0, height: 7.0), title: "5:7"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 9.0, height: 16.0), title: "9:16")
        ]
    }

    public static func landscapePresets() -> [CMCropViewControllerAspectRatioPreset] {
        let object = CMCropViewControllerAspectRatioPreset(size: .zero, title: "Original")
        let resourceBundle = CM_CROP_VIEW_RESOURCE_BUNDLE_FOR_OBJECT(object)
        return [
            CMCropViewControllerAspectRatioPreset(size: .zero,
                                                  title: NSLocalizedString("Original", tableName: "TOCropViewControllerLocalizable", bundle: resourceBundle, value: "Original", comment: "")),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 1.0, height: 1.0),
                                                  title: NSLocalizedString("Square", tableName: "TOCropViewControllerLocalizable", bundle: resourceBundle, value: "Square", comment: "")),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 3.0, height: 2.0), title: "3:2"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 5.0, height: 3.0), title: "5:3"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 4.0, height: 3.0), title: "4:3"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 5.0, height: 4.0), title: "5:4"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 7.0, height: 5.0), title: "7:5"),
            CMCropViewControllerAspectRatioPreset(size: CGSize(width: 16.0, height: 9.0), title: "16:9")
        ]
    }
}
