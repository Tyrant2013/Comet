import UIKit

@objcMembers
public final class CMActivityCroppedImageProvider: UIActivityItemProvider, @unchecked Sendable {
    public private(set) var image: UIImage
    public private(set) var cropFrame: CGRect
    public private(set) var angle: Int
    public private(set) var circular: Bool

    private var croppedImage: UIImage?

    public init(image: UIImage, cropFrame: CGRect, angle: Int, circular: Bool) {
        self.image = image
        self.cropFrame = cropFrame
        self.angle = angle
        self.circular = circular
        super.init(placeholderItem: UIImage())
    }

    public override func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        UIImage()
    }

    public override func activityViewController(_ activityViewController: UIActivityViewController,
                                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        croppedImage
    }

    public override var item: Any {
        if angle == 0 && cropFrame.equalTo(CGRect(origin: .zero, size: image.size)) {
            croppedImage = image
            return image
        }

        let image = image.cm_croppedImage(frame: cropFrame, angle: angle, circularClip: circular)
        croppedImage = image
        return image
    }
}
