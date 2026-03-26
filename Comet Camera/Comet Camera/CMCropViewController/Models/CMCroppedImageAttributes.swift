import Foundation
import UIKit

@objcMembers
public final class CMCroppedImageAttributes: NSObject {
    public private(set) var angle: Int
    public private(set) var croppedFrame: CGRect
    public private(set) var originalImageSize: CGSize

    public init(croppedFrame: CGRect, angle: Int, originalImageSize: CGSize) {
        self.angle = angle
        self.croppedFrame = croppedFrame
        self.originalImageSize = originalImageSize
        super.init()
    }
}
