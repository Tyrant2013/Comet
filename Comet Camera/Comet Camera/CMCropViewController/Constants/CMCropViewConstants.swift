import Foundation
import UIKit

@objc public enum CMCropViewCroppingStyle: Int {
    case `default`
    case circular
}

@objc public enum CMCropViewControllerToolbarPosition: Int {
    case bottom
    case top
}

//public func CM_CROP_VIEW_RESOURCE_BUNDLE_FOR_OBJECT(_ object: NSObject) -> Bundle {
//    #if SWIFT_PACKAGE
//    let bundleName = "CMCropViewController_CMCropViewController"
//    #else
//    let bundleName = "CMCropViewControllerBundle"
//    #endif
//
//    let classBundle = Bundle(for: type(of: object))
//    if let resourceBundleURL = classBundle.url(forResource: bundleName, withExtension: "bundle"),
//       let resourceBundle = Bundle(url: resourceBundleURL) {
//        return resourceBundle
//    }
//
//    return classBundle
//}
