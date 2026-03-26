import QuartzCore
import UIKit

@objcMembers
public final class CMCropViewControllerTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    public var isDismissing = false
    public var image: UIImage?

    public weak var fromView: UIView?
    public weak var toView: UIView?

    public var fromFrame: CGRect = .zero
    public var toFrame: CGRect = .zero

    public var prepareForTransitionHandler: (() -> Void)?

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.45
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView

        guard let fromViewController = transitionContext.viewController(forKey: .from),
              let toViewController = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        let cropViewController = isDismissing ? fromViewController : toViewController
        let previousController = isDismissing ? toViewController : fromViewController

        cropViewController.view.frame = containerView.bounds
        if isDismissing {
            previousController.view.frame = containerView.bounds
        }

        if !isDismissing {
            containerView.addSubview(cropViewController.view)
            cropViewController.view.setNeedsLayout()
            cropViewController.view.layoutIfNeeded()
            cropViewController.viewDidLayoutSubviews()
        } else {
            containerView.insertSubview(previousController.view, belowSubview: cropViewController.view)
        }

        prepareForTransitionHandler?()

        if !isDismissing, let fromView,
           let superview = fromView.superview {
            fromFrame = superview.convert(fromView.frame, to: containerView)
        } else if isDismissing, let toView,
                  let superview = toView.superview {
            toFrame = superview.convert(toView.frame, to: containerView)
        }

        var imageView: UIImageView?
        if (isDismissing && !toFrame.isEmpty) || (!isDismissing && !fromFrame.isEmpty) {
            let transitionImageView = UIImageView(image: image)
            transitionImageView.frame = fromFrame
            transitionImageView.accessibilityIgnoresInvertColors = true
            containerView.addSubview(transitionImageView)
            imageView = transitionImageView
        }

        cropViewController.view.alpha = isDismissing ? 1.0 : 0.0

        if let imageView {
            UIView.animate(withDuration: transitionDuration(using: transitionContext),
                           delay: 0.0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.7,
                           options: [],
                           animations: {
                imageView.frame = self.toFrame
            }, completion: { _ in
                UIView.animate(withDuration: 0.25, animations: {
                    imageView.alpha = 0.0
                }, completion: { _ in
                    imageView.removeFromSuperview()
                })
            })
        }

        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            cropViewController.view.alpha = self.isDismissing ? 0.0 : 1.0
        }, completion: { _ in
            self.reset()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }

    public func reset() {
        image = nil
        toView = nil
        fromView = nil
        fromFrame = .zero
        toFrame = .zero
        prepareForTransitionHandler = nil
    }
}
