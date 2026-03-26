import UIKit

public final class CMCropScrollView: UIScrollView {
    public var touchesBegan: (() -> Void)?
    public var touchesCancelled: (() -> Void)?
    public var touchesEnded: (() -> Void)?

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan?()
        super.touchesBegan(touches, with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesCancelled?()
        super.touchesCancelled(touches, with: event)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded?()
        super.touchesEnded(touches, with: event)
    }
}
