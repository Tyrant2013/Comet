import UIKit

private let CM_CROPVIEW_BACKGROUND_COLOR = UIColor(white: 0.12, alpha: 1.0)
private let kCMCropViewPadding: CGFloat = 14.0
private let kCMCropTimerDuration: TimeInterval = 0.8
private let kCMCropViewMinimumBoxSize: CGFloat = 42.0
private let kCMMaximumZoomScale: CGFloat = 15.0

private enum CMCropViewOverlayEdge: Int {
    case none
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

@objc public protocol CMCropViewDelegate: AnyObject {
    func cropViewDidBecomeResettable(_ cropView: CMCropView)
    func cropViewDidBecomeNonResettable(_ cropView: CMCropView)
}

public final class CMCropView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    public private(set) var image: UIImage
    public private(set) var croppingStyle: CMCropViewCroppingStyle

    private let backgroundImageView: UIImageView
    private let backgroundContainerView: UIView
    public private(set) var foregroundContainerView = UIView()
    private let foregroundImageView: UIImageView
    private let scrollView = CMCropScrollView(frame: .zero)
    public private(set) var overlayView = UIView()
    private let translucencyView: UIView
    private let translucencyEffect: UIVisualEffect?
    public private(set) var gridOverlayView = CMCropOverlayView(frame: .zero)

    private var gridPanGestureRecognizer: UIPanGestureRecognizer?

    private var applyInitialCroppedImageFrame = false
    private var tappedEdge: CMCropViewOverlayEdge = .none
    private var cropOriginFrame: CGRect = .zero
    private var panOriginPoint: CGPoint = .zero
    public private(set) var cropBoxFrame: CGRect = .zero
    private var resetTimer: Timer?
    private var editing = false
    private var disableForegroundMatching = false

    private var rotationContentOffset: CGPoint = .zero
    private var rotationContentSize: CGSize = .zero
    private var rotationBoundFrame: CGRect = .zero

    private var cropBoxLastEditedSize: CGSize = .zero
    private var cropBoxLastEditedAngle: Int = 0
    private var cropBoxLastEditedZoomScale: CGFloat = 1.0
    private var cropBoxLastEditedMinZoomScale: CGFloat = 1.0
    private var rotateAnimationInProgress = false

    private var originalCropBoxSize: CGSize = .zero
    private var originalContentOffset: CGPoint = .zero
    public private(set) var canBeReset = false {
        didSet {
            if oldValue == canBeReset { return }
            if canBeReset {
                delegate?.cropViewDidBecomeResettable(self)
            } else {
                delegate?.cropViewDidBecomeNonResettable(self)
            }
        }
    }

    private let dynamicBlurEffect: Bool
    private var restoreAngle: Int = 0
    private var restoreImageCropFrame: CGRect = .zero
    private var initialSetupPerformed = false

    public weak var delegate: CMCropViewDelegate?

    public var cropBoxResizeEnabled: Bool = true {
        didSet { gridPanGestureRecognizer?.isEnabled = cropBoxResizeEnabled }
    }

    public var cropRegionInsets: UIEdgeInsets = .zero
    public var simpleRenderMode: Bool = false
    public var internalLayoutDisabled = false
    public var aspectRatio: CGSize = .zero
    public var aspectRatioLockEnabled = false
    public var aspectRatioLockDimensionSwapEnabled = false
    public var resetAspectRatioEnabled = true
    public var cropBoxAspectRatioIsPortrait: Bool { cropBoxFrame.width < cropBoxFrame.height }

    private var internalAngle: Int = 0
    public var angle: Int {
        get { internalAngle }
        set { setAngle(newValue) }
    }

    private var internalCroppingViewsHidden = false
    public var croppingViewsHidden: Bool {
        get { internalCroppingViewsHidden }
        set { setCroppingViewsHiddenInternal(newValue, animated: false) }
    }

    public var imageCropFrame: CGRect {
        get { computeImageCropFrame() }
        set { setImageCropFrame(newValue) }
    }

    private var internalGridOverlayHidden = false
    public var gridOverlayHidden: Bool {
        get { internalGridOverlayHidden }
        set { setGridOverlayHiddenInternal(newValue, animated: false) }
    }

    public var cropViewPadding: CGFloat = kCMCropViewPadding
    public var cropAdjustingDelay: TimeInterval = kCMCropTimerDuration
    public var minimumAspectRatio: CGFloat = 0.0
    public var maximumZoomScale: CGFloat = kCMMaximumZoomScale

    public var alwaysShowCroppingGrid = false {
        didSet {
            if alwaysShowCroppingGrid == oldValue { return }
            gridOverlayView.setGridHidden(!alwaysShowCroppingGrid, animated: true)
        }
    }

    public var translucencyAlwaysHidden = false {
        didSet {
            if translucencyAlwaysHidden == oldValue { return }
            translucencyView.isHidden = translucencyAlwaysHidden
        }
    }

    public var imageViewFrame: CGRect {
        CGRect(x: -scrollView.contentOffset.x, y: -scrollView.contentOffset.y, width: scrollView.contentSize.width, height: scrollView.contentSize.height)
    }

    private var contentBounds: CGRect {
        CGRect(x: cropViewPadding + cropRegionInsets.left,
               y: cropViewPadding + cropRegionInsets.top,
               width: frame.width - ((cropViewPadding * 2) + cropRegionInsets.left + cropRegionInsets.right),
               height: frame.height - ((cropViewPadding * 2) + cropRegionInsets.top + cropRegionInsets.bottom))
    }

    private var imageSize: CGSize {
        if angle == -90 || angle == -270 || angle == 90 || angle == 270 {
            return CGSize(width: image.size.height, height: image.size.width)
        }
        return image.size
    }

    private var hasAspectRatio: Bool {
        aspectRatio.width > .ulpOfOne && aspectRatio.height > .ulpOfOne
    }

    public init(image: UIImage) {
        self.image = image
        self.croppingStyle = .default
        self.backgroundImageView = UIImageView(image: image)
        self.backgroundContainerView = UIView(frame: CGRect(origin: .zero, size: image.size))
        self.foregroundImageView = UIImageView(image: image)

        if NSClassFromString("UIVisualEffectView") != nil {
            let effect = UIBlurEffect(style: .dark)
            self.translucencyEffect = effect
            self.translucencyView = UIVisualEffectView(effect: effect)
        } else {
            let toolbar = UIToolbar()
            toolbar.barStyle = .black
            self.translucencyEffect = nil
            self.translucencyView = toolbar
        }

        self.dynamicBlurEffect = UIDevice.current.systemVersion.compare("9.0", options: .numeric) != .orderedAscending

        super.init(frame: .zero)
        setup()
    }

    public init(croppingStyle: CMCropViewCroppingStyle, image: UIImage) {
        self.image = image
        self.croppingStyle = croppingStyle
        self.backgroundImageView = UIImageView(image: image)
        self.backgroundContainerView = UIView(frame: CGRect(origin: .zero, size: image.size))
        self.foregroundImageView = UIImageView(image: image)

        if NSClassFromString("UIVisualEffectView") != nil {
            let effect = UIBlurEffect(style: .dark)
            self.translucencyEffect = effect
            self.translucencyView = UIVisualEffectView(effect: effect)
        } else {
            let toolbar = UIToolbar()
            toolbar.barStyle = .black
            self.translucencyEffect = nil
            self.translucencyView = toolbar
        }

        self.dynamicBlurEffect = UIDevice.current.systemVersion.compare("9.0", options: .numeric) != .orderedAscending

        super.init(frame: .zero)
        setup()
    }

    public required init?(coder: NSCoder) { nil }

    private func setup() {
        let circularMode = croppingStyle == .circular

        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = CM_CROPVIEW_BACKGROUND_COLOR
        cropBoxFrame = .zero
        applyInitialCroppedImageFrame = false
        editing = false
        cropBoxResizeEnabled = !circularMode
        aspectRatio = circularMode ? CGSize(width: 1.0, height: 1.0) : .zero
        resetAspectRatioEnabled = !circularMode
        restoreImageCropFrame = .zero
        restoreAngle = 0
        cropAdjustingDelay = kCMCropTimerDuration
        cropViewPadding = kCMCropViewPadding
        maximumZoomScale = kCMMaximumZoomScale

        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        addSubview(scrollView)

        scrollView.touchesBegan = { [weak self] in self?.startEditing() }
        scrollView.touchesEnded = { [weak self] in self?.startResetTimer() }

        backgroundImageView.layer.minificationFilter = .trilinear
        backgroundContainerView.addSubview(backgroundImageView)
        scrollView.addSubview(backgroundContainerView)

        overlayView.frame = bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = backgroundColor?.withAlphaComponent(0.35)
        overlayView.isHidden = false
        overlayView.isUserInteractionEnabled = false
        addSubview(overlayView)

        translucencyView.frame = bounds.insetBy(dx: NSClassFromString("UIVisualEffectView") == nil ? -1.0 : 0.0,
                                                dy: NSClassFromString("UIVisualEffectView") == nil ? -1.0 : 0.0)
        translucencyView.isHidden = translucencyAlwaysHidden
        translucencyView.isUserInteractionEnabled = false
        translucencyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(translucencyView)

        foregroundContainerView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        foregroundContainerView.clipsToBounds = true
        foregroundContainerView.isUserInteractionEnabled = false
        addSubview(foregroundContainerView)

        foregroundImageView.layer.minificationFilter = .trilinear
        foregroundContainerView.addSubview(foregroundImageView)

        foregroundImageView.accessibilityIgnoresInvertColors = true
        backgroundImageView.accessibilityIgnoresInvertColors = true

        if circularMode { return }

        gridOverlayView = CMCropOverlayView(frame: foregroundContainerView.frame)
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.gridHidden = true
        addSubview(gridOverlayView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(gridPanGestureRecognized(_:)))
        pan.delegate = self
        scrollView.panGestureRecognizer.require(toFail: pan)
        addGestureRecognizer(pan)
        gridPanGestureRecognizer = pan
    }

    public func performInitialSetup() {
        if initialSetupPerformed { return }
        initialSetupPerformed = true

        layoutInitialImage()

        if restoreAngle != 0 {
            setAngle(restoreAngle)
            restoreAngle = 0
            cropBoxLastEditedAngle = angle
        }

        if !restoreImageCropFrame.isEmpty {
            setImageCropFrame(restoreImageCropFrame)
            restoreImageCropFrame = .zero
        }

        captureStateForImageRotation()
        checkForCanReset()
    }

    private func layoutInitialImage() {
        let imageSize = self.imageSize
        scrollView.contentSize = imageSize

        let bounds = contentBounds
        let boundsSize = bounds.size

        var scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let scaledImageSize = CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))

        var cropBoxSize = CGSize.zero
        if hasAspectRatio {
            let ratioScale = aspectRatio.width / aspectRatio.height
            let fullSizeRatio = CGSize(width: boundsSize.height * ratioScale, height: boundsSize.height)
            let fitScale = min(boundsSize.width / fullSizeRatio.width, boundsSize.height / fullSizeRatio.height)
            cropBoxSize = CGSize(width: fullSizeRatio.width * fitScale, height: fullSizeRatio.height * fitScale)
            scale = max(cropBoxSize.width / imageSize.width, cropBoxSize.height / imageSize.height)
        }

        let scaledSize = CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))
        scrollView.minimumZoomScale = scale
        scrollView.maximumZoomScale = scale * maximumZoomScale

        var frame = CGRect.zero
        frame.size = hasAspectRatio ? cropBoxSize : scaledSize
        frame.origin.x = floor(bounds.origin.x + floor((bounds.width - frame.width) * 0.5))
        frame.origin.y = floor(bounds.origin.y + floor((bounds.height - frame.height) * 0.5))
        setCropBoxFrameInternal(frame)

        scrollView.zoomScale = scrollView.minimumZoomScale
        scrollView.contentSize = scaledSize

        if frame.width < scaledSize.width - .ulpOfOne || frame.height < scaledSize.height - .ulpOfOne {
            var offset = CGPoint.zero
            offset.x = -floor(bounds.midX - (scaledSize.width * 0.5))
            offset.y = -floor(bounds.midY - (scaledSize.height * 0.5))
            scrollView.contentOffset = offset
        }

        cropBoxLastEditedAngle = 0
        captureStateForImageRotation()

        originalCropBoxSize = resetAspectRatioEnabled ? scaledImageSize : cropBoxFrame.size
        originalContentOffset = scrollView.contentOffset

        checkForCanReset()
        matchForegroundToBackground()
    }

    public func prepareforRotation() {
        rotationContentOffset = scrollView.contentOffset
        rotationContentSize = scrollView.contentSize
        rotationBoundFrame = contentBounds
    }

    public func performRelayoutForRotation() {
        var cropFrame = cropBoxFrame
        let contentFrame = contentBounds

        let scale = min(contentFrame.width / cropFrame.width, contentFrame.height / cropFrame.height)
        scrollView.minimumZoomScale *= scale
        scrollView.zoomScale *= scale

        cropFrame.size.width = floor(cropFrame.width * scale)
        cropFrame.size.height = floor(cropFrame.height * scale)
        cropFrame.origin.x = floor(contentFrame.origin.x + ((contentFrame.width - cropFrame.width) * 0.5))
        cropFrame.origin.y = floor(contentFrame.origin.y + ((contentFrame.height - cropFrame.height) * 0.5))
        setCropBoxFrameInternal(cropFrame)

        captureStateForImageRotation()

        let oldMidPoint = CGPoint(x: rotationBoundFrame.midX, y: rotationBoundFrame.midY)
        let contentCenter = CGPoint(x: rotationContentOffset.x + oldMidPoint.x, y: rotationContentOffset.y + oldMidPoint.y)

        let normalizedCenter = CGPoint(x: contentCenter.x / rotationContentSize.width, y: contentCenter.y / rotationContentSize.height)
        let newMidPoint = CGPoint(x: contentBounds.midX, y: contentBounds.midY)

        let translatedContentOffset = CGPoint(x: scrollView.contentSize.width * normalizedCenter.x,
                                              y: scrollView.contentSize.height * normalizedCenter.y)

        var offset = CGPoint(x: floor(translatedContentOffset.x - newMidPoint.x),
                             y: floor(translatedContentOffset.y - newMidPoint.y))

        offset.x = max(-scrollView.contentInset.left, offset.x)
        offset.y = max(-scrollView.contentInset.top, offset.y)

        let maximumOffset = CGPoint(x: (bounds.width - scrollView.contentInset.right) + scrollView.contentSize.width,
                                    y: (bounds.height - scrollView.contentInset.bottom) + scrollView.contentSize.height)
        offset.x = min(offset.x, maximumOffset.x)
        offset.y = min(offset.y, maximumOffset.y)
        scrollView.contentOffset = offset

        matchForegroundToBackground()
    }

    private func matchForegroundToBackground() {
        if disableForegroundMatching { return }
        foregroundImageView.frame = backgroundContainerView.superview?.convert(backgroundContainerView.frame, to: foregroundContainerView) ?? .zero
    }

    private func setCropBoxFrameInternal(_ proposedFrame: CGRect) {
        var cropBoxFrame = proposedFrame
        if cropBoxFrame == self.cropBoxFrame { return }

        let frameSize = cropBoxFrame.size
        if frameSize.width < .ulpOfOne || frameSize.height < .ulpOfOne { return }
        if frameSize.width.isNaN || frameSize.height.isNaN { return }

        let contentFrame = contentBounds
        let xOrigin = ceil(contentFrame.origin.x)
        let xDelta = cropBoxFrame.origin.x - xOrigin
        cropBoxFrame.origin.x = floor(max(cropBoxFrame.origin.x, xOrigin))
        if xDelta < -.ulpOfOne { cropBoxFrame.size.width += xDelta }

        let yOrigin = ceil(contentFrame.origin.y)
        let yDelta = cropBoxFrame.origin.y - yOrigin
        cropBoxFrame.origin.y = floor(max(cropBoxFrame.origin.y, yOrigin))
        if yDelta < -.ulpOfOne { cropBoxFrame.size.height += yDelta }

        let maxWidth = (contentFrame.width + contentFrame.origin.x) - cropBoxFrame.origin.x
        cropBoxFrame.size.width = floor(min(cropBoxFrame.size.width, maxWidth))

        let maxHeight = (contentFrame.height + contentFrame.origin.y) - cropBoxFrame.origin.y
        cropBoxFrame.size.height = floor(min(cropBoxFrame.size.height, maxHeight))

        cropBoxFrame.size.width = max(cropBoxFrame.width, kCMCropViewMinimumBoxSize)
        cropBoxFrame.size.height = max(cropBoxFrame.height, kCMCropViewMinimumBoxSize)

        self.cropBoxFrame = cropBoxFrame
        foregroundContainerView.frame = cropBoxFrame
        gridOverlayView.frame = cropBoxFrame

        if croppingStyle == .circular {
            foregroundContainerView.layer.cornerRadius = foregroundContainerView.frame.width * 0.5
        }

        scrollView.contentInset = UIEdgeInsets(top: cropBoxFrame.minY,
                                               left: cropBoxFrame.minX,
                                               bottom: bounds.maxY - cropBoxFrame.maxY,
                                               right: bounds.maxX - cropBoxFrame.maxX)

        let imageSize = backgroundContainerView.bounds.size
        let scale = max(cropBoxFrame.height / imageSize.height, cropBoxFrame.width / imageSize.width)
        scrollView.minimumZoomScale = scale

        var size = scrollView.contentSize
        size.width = floor(size.width)
        size.height = floor(size.height)
        scrollView.contentSize = size

        scrollView.zoomScale = scrollView.zoomScale
        matchForegroundToBackground()
    }

    public func resetLayoutToDefaultAnimated(_ animated: Bool) {
        if hasAspectRatio && resetAspectRatioEnabled {
            aspectRatio = .zero
        }

        if !animated || angle != 0 {
            internalAngle = 0
            scrollView.zoomScale = 1.0

            let imageRect = CGRect(origin: .zero, size: image.size)
            backgroundImageView.transform = .identity
            backgroundContainerView.transform = .identity
            backgroundImageView.frame = imageRect
            backgroundContainerView.frame = imageRect

            foregroundImageView.transform = .identity
            foregroundImageView.frame = imageRect

            layoutInitialImage()
            checkForCanReset()
            return
        }

        if resetTimer != nil {
            cancelResetTimer()
            setEditing(false, resetCropBox: false, animated: false)
        }

        setSimpleRenderMode(true, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 1.0,
                           options: .beginFromCurrentState,
                           animations: {
                self.layoutInitialImage()
            }, completion: { _ in
                self.setSimpleRenderMode(false, animated: true)
            })
        }
    }

    private func toggleTranslucencyViewVisible(_ visible: Bool) {
        if !dynamicBlurEffect {
            translucencyView.alpha = visible ? 1.0 : 0.0
        } else if let visual = translucencyView as? UIVisualEffectView {
            visual.effect = visible ? translucencyEffect : nil
        }
    }

    private func updateToImageCropFrame(_ imageCropframe: CGRect) {
        let minimumSize = scrollView.minimumZoomScale
        let scaledOffset = CGPoint(x: imageCropframe.origin.x * minimumSize, y: imageCropframe.origin.y * minimumSize)
        let scaledCropSize = CGSize(width: imageCropframe.width * minimumSize, height: imageCropframe.height * minimumSize)

        let bounds = contentBounds
        let scale = min(bounds.width / scaledCropSize.width, bounds.height / scaledCropSize.height)

        scrollView.zoomScale = scrollView.minimumZoomScale * scale

        var contentSize = scrollView.contentSize
        contentSize.width = floor(contentSize.width)
        contentSize.height = floor(contentSize.height)
        scrollView.contentSize = contentSize

        var frame = CGRect.zero
        frame.size = CGSize(width: floor(scaledCropSize.width * scale), height: floor(scaledCropSize.height * scale))

        var cropBoxFrame = CGRect.zero
        cropBoxFrame.size = frame.size
        cropBoxFrame.origin.x = floor(bounds.midX - (frame.width * 0.5))
        cropBoxFrame.origin.y = floor(bounds.midY - (frame.height * 0.5))
        setCropBoxFrameInternal(cropBoxFrame)

        frame.origin.x = ceil((scaledOffset.x * scale) - scrollView.contentInset.left)
        frame.origin.y = ceil((scaledOffset.y * scale) - scrollView.contentInset.top)
        scrollView.contentOffset = frame.origin
    }

    @objc private func gridPanGestureRecognized(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)

        if recognizer.state == .began {
            startEditing()
            panOriginPoint = point
            cropOriginFrame = cropBoxFrame
            tappedEdge = cropEdgeForPoint(panOriginPoint)
        }

        if recognizer.state == .ended {
            startResetTimer()
        }

        updateCropBoxFrameWithGesturePoint(point)
    }

    private func updateCropBoxFrameWithGesturePoint(_ point: CGPoint) {
        var frame = cropBoxFrame
        let originFrame = cropOriginFrame
        let contentFrame = contentBounds

        var p = point
        p.x = max(contentFrame.origin.x - cropViewPadding, p.x)
        p.y = max(contentFrame.origin.y - cropViewPadding, p.y)

        var xDelta = ceil(p.x - panOriginPoint.x)
        var yDelta = ceil(p.y - panOriginPoint.y)

        let ratio = originFrame.width / originFrame.height
        var aspectHorizontal = false
        var aspectVertical = false
        var clampMinFromTop = false
        var clampMinFromLeft = false

        switch tappedEdge {
        case .left:
            if aspectRatioLockEnabled {
                aspectHorizontal = true
                xDelta = max(xDelta, 0)
                let scaleOrigin = CGPoint(x: originFrame.maxX, y: originFrame.midY)
                frame.size.height = frame.size.width / ratio
                frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
            }
            let newWidth = originFrame.width - xDelta
            let newHeight = originFrame.height
            if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                frame.origin.x = originFrame.origin.x + xDelta
                frame.size.width = originFrame.width - xDelta
            }
            clampMinFromLeft = true
        case .right:
            if aspectRatioLockEnabled {
                aspectHorizontal = true
                let scaleOrigin = CGPoint(x: originFrame.minX, y: originFrame.midY)
                frame.size.height = frame.size.width / ratio
                frame.origin.y = scaleOrigin.y - (frame.size.height * 0.5)
                frame.size.width = originFrame.width + xDelta
                frame.size.width = min(frame.size.width, contentFrame.height * ratio)
            } else {
                let newWidth = originFrame.width + xDelta
                let newHeight = originFrame.height
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.size.width = originFrame.width + xDelta
                }
            }
        case .bottom:
            if aspectRatioLockEnabled {
                aspectVertical = true
                let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.minY)
                frame.size.width = frame.size.height * ratio
                frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
                frame.size.height = originFrame.height + yDelta
                frame.size.height = min(frame.size.height, contentFrame.width / ratio)
            } else {
                let newWidth = originFrame.width
                let newHeight = originFrame.height + yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.size.height = originFrame.height + yDelta
                }
            }
        case .top:
            if aspectRatioLockEnabled {
                aspectVertical = true
                yDelta = max(0, yDelta)
                let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.maxY)
                frame.size.width = frame.size.height * ratio
                frame.origin.x = scaleOrigin.x - (frame.size.width * 0.5)
                frame.origin.y = originFrame.origin.y + yDelta
                frame.size.height = originFrame.height - yDelta
            } else {
                let newWidth = originFrame.width
                let newHeight = originFrame.height - yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.height - yDelta
                }
            }
            clampMinFromTop = true
        case .topLeft:
            if aspectRatioLockEnabled {
                xDelta = max(xDelta, 0); yDelta = max(yDelta, 0)
                let dx = 1.0 - (xDelta / originFrame.width)
                let dy = 1.0 - (yDelta / originFrame.height)
                let scale = (dx + dy) * 0.5
                frame.size.width = ceil(originFrame.width * scale)
                frame.size.height = ceil(originFrame.height * scale)
                frame.origin.x = originFrame.origin.x + (originFrame.width - frame.width)
                frame.origin.y = originFrame.origin.y + (originFrame.height - frame.height)
                aspectHorizontal = true; aspectVertical = true
            } else {
                let newWidth = originFrame.width - xDelta
                let newHeight = originFrame.height - yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.origin.x = originFrame.origin.x + xDelta
                    frame.size.width = originFrame.width - xDelta
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.height - yDelta
                }
            }
            clampMinFromTop = true; clampMinFromLeft = true
        case .topRight:
            if aspectRatioLockEnabled {
                xDelta = min(xDelta, 0); yDelta = max(yDelta, 0)
                let dx = 1.0 - ((-xDelta) / originFrame.width)
                let dy = 1.0 - (yDelta / originFrame.height)
                let scale = (dx + dy) * 0.5
                frame.size.width = ceil(originFrame.width * scale)
                frame.size.height = ceil(originFrame.height * scale)
                frame.origin.y = originFrame.origin.y + (originFrame.height - frame.height)
                aspectHorizontal = true; aspectVertical = true
            } else {
                let newWidth = originFrame.width + xDelta
                let newHeight = originFrame.height - yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.size.width = originFrame.width + xDelta
                    frame.origin.y = originFrame.origin.y + yDelta
                    frame.size.height = originFrame.height - yDelta
                }
            }
            clampMinFromTop = true
        case .bottomLeft:
            if aspectRatioLockEnabled {
                let dx = 1.0 - (xDelta / originFrame.width)
                let dy = 1.0 - (-yDelta / originFrame.height)
                let scale = (dx + dy) * 0.5
                frame.size.width = ceil(originFrame.width * scale)
                frame.size.height = ceil(originFrame.height * scale)
                frame.origin.x = originFrame.maxX - frame.width
                aspectHorizontal = true; aspectVertical = true
            } else {
                let newWidth = originFrame.width - xDelta
                let newHeight = originFrame.height + yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.size.height = originFrame.height + yDelta
                    frame.origin.x = originFrame.origin.x + xDelta
                    frame.size.width = originFrame.width - xDelta
                }
            }
            clampMinFromLeft = true
        case .bottomRight:
            if aspectRatioLockEnabled {
                let dx = 1.0 - ((-1 * xDelta) / originFrame.width)
                let dy = 1.0 - ((-1 * yDelta) / originFrame.height)
                let scale = (dx + dy) * 0.5
                frame.size.width = ceil(originFrame.width * scale)
                frame.size.height = ceil(originFrame.height * scale)
                aspectHorizontal = true; aspectVertical = true
            } else {
                let newWidth = originFrame.width + xDelta
                let newHeight = originFrame.height + yDelta
                if min(newHeight, newWidth) / max(newHeight, newWidth) >= minimumAspectRatio {
                    frame.size.height = originFrame.height + yDelta
                    frame.size.width = originFrame.width + xDelta
                }
            }
        case .none:
            break
        }

        var minSize = CGSize(width: kCMCropViewMinimumBoxSize, height: kCMCropViewMinimumBoxSize)
        var maxSize = CGSize(width: contentFrame.width, height: contentFrame.height)

        if aspectRatioLockEnabled && aspectHorizontal {
            maxSize.height = contentFrame.width / ratio
            minSize.width = kCMCropViewMinimumBoxSize * ratio
        }
        if aspectRatioLockEnabled && aspectVertical {
            maxSize.width = contentFrame.height * ratio
            minSize.height = kCMCropViewMinimumBoxSize / ratio
        }

        if clampMinFromLeft {
            let maxWidth = cropOriginFrame.maxX - contentFrame.origin.x
            frame.size.width = min(frame.width, maxWidth)
        }
        if clampMinFromTop {
            let maxHeight = cropOriginFrame.maxY - contentFrame.origin.y
            frame.size.height = min(frame.height, maxHeight)
        }

        frame.size.width = max(frame.width, minSize.width)
        frame.size.height = max(frame.height, minSize.height)
        frame.size.width = min(frame.width, maxSize.width)
        frame.size.height = min(frame.height, maxSize.height)

        frame.origin.x = max(frame.origin.x, contentFrame.minX)
        frame.origin.x = min(frame.origin.x, contentFrame.maxX - minSize.width)
        frame.origin.y = max(frame.origin.y, contentFrame.minY)
        frame.origin.y = min(frame.origin.y, contentFrame.maxY - minSize.height)

        if clampMinFromLeft && frame.width <= minSize.width + .ulpOfOne {
            frame.origin.x = originFrame.maxX - minSize.width
        }
        if clampMinFromTop && frame.height <= minSize.height + .ulpOfOne {
            frame.origin.y = originFrame.maxY - minSize.height
        }

        setCropBoxFrameInternal(frame)
        checkForCanReset()
    }

    @objc private func timerTriggered() {
        setEditing(false, resetCropBox: true, animated: true)
        resetTimer?.invalidate()
        resetTimer = nil
    }

    private func startResetTimer() {
        if resetTimer != nil { return }
        resetTimer = Timer.scheduledTimer(timeInterval: cropAdjustingDelay, target: self, selector: #selector(timerTriggered), userInfo: nil, repeats: false)
    }

    private func cancelResetTimer() {
        resetTimer?.invalidate()
        resetTimer = nil
    }

    private func cropEdgeForPoint(_ point: CGPoint) -> CMCropViewOverlayEdge {
        let frame = cropBoxFrame.insetBy(dx: -32.0, dy: -32.0)

        let topLeft = CGRect(x: frame.origin.x, y: frame.origin.y, width: 64, height: 64)
        if topLeft.contains(point) { return .topLeft }

        var topRight = topLeft
        topRight.origin.x = frame.maxX - 64.0
        if topRight.contains(point) { return .topRight }

        var bottomLeft = topLeft
        bottomLeft.origin.y = frame.maxY - 64.0
        if bottomLeft.contains(point) { return .bottomLeft }

        var bottomRight = topRight
        bottomRight.origin.y = bottomLeft.origin.y
        if bottomRight.contains(point) { return .bottomRight }

        let top = CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: 64)
        if top.contains(point) { return .top }

        var bottom = top
        bottom.origin.y = frame.maxY - 64
        if bottom.contains(point) { return .bottom }

        let left = CGRect(x: frame.origin.x, y: frame.origin.y, width: 64, height: frame.height)
        if left.contains(point) { return .left }

        var right = left
        right.origin.x = frame.maxX - 64
        if right.contains(point) { return .right }

        return .none
    }

    private func computeImageCropFrame() -> CGRect {
        let imageSize = self.imageSize
        let contentSize = scrollView.contentSize
        let cropBox = cropBoxFrame
        let contentOffset = scrollView.contentOffset
        let edgeInsets = scrollView.contentInset
        let scale = min(imageSize.width / contentSize.width, imageSize.height / contentSize.height)

        var frame = CGRect.zero
        frame.origin.x = floor((floor(contentOffset.x) + edgeInsets.left) * (imageSize.width / contentSize.width))
        frame.origin.x = max(0, frame.origin.x)
        frame.origin.y = floor((floor(contentOffset.y) + edgeInsets.top) * (imageSize.height / contentSize.height))
        frame.origin.y = max(0, frame.origin.y)

        frame.size.width = ceil(cropBox.width * scale)
        frame.size.width = min(imageSize.width, frame.width)

        if floor(cropBox.width) == floor(cropBox.height) {
            frame.size.height = frame.width
        } else {
            frame.size.height = ceil(cropBox.height * scale)
        }
        frame.size.height = min(imageSize.height, frame.height)
        return frame
    }

    private func setImageCropFrame(_ imageCropFrame: CGRect) {
        if !initialSetupPerformed {
            restoreImageCropFrame = imageCropFrame
            return
        }
        updateToImageCropFrame(imageCropFrame)
    }

    private func setAngle(_ angle: Int) {
        var newAngle = angle
        if angle % 90 != 0 { newAngle = 0 }

        if !initialSetupPerformed {
            restoreAngle = newAngle
            return
        }

        if newAngle >= 0 {
            while abs(self.angle) != abs(newAngle) {
                rotateImageNinetyDegreesAnimated(false, clockwise: true, completion: nil)
            }
        } else {
            while -abs(self.angle) != -abs(newAngle) {
                rotateImageNinetyDegreesAnimated(false, clockwise: false, completion: nil)
            }
        }
    }

    private func startEditing() {
        cancelResetTimer()
        setEditing(true, resetCropBox: false, animated: true)
    }

    private func setEditing(_ editing: Bool, resetCropBox: Bool, animated: Bool) {
        if editing == self.editing { return }
        self.editing = editing

        var hidden = !editing
        if alwaysShowCroppingGrid { hidden = false }
        gridOverlayView.setGridHidden(hidden, animated: animated)

        if resetCropBox {
            moveCroppedContentToCenterAnimated(animated)
            captureStateForImageRotation()
            cropBoxLastEditedAngle = angle
        }

        if !animated {
            toggleTranslucencyViewVisible(!editing)
            return
        }

        let duration: TimeInterval = editing ? 0.05 : 0.35
        var delay: TimeInterval = editing ? 0.0 : 0.35
        if croppingStyle == .circular { delay = 0.0 }

        UIView.animateKeyframes(withDuration: duration, delay: delay, options: [], animations: {
            self.toggleTranslucencyViewVisible(!editing)
        })
    }

    public func moveCroppedContentToCenterAnimated(_ animated: Bool) {
        if internalLayoutDisabled { return }
        let contentRect = contentBounds
        var cropFrame = cropBoxFrame
        if cropFrame.width < .ulpOfOne || cropFrame.height < .ulpOfOne { return }

        let scale = min(contentRect.width / cropFrame.width, contentRect.height / cropFrame.height)
        let focusPoint = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let midPoint = CGPoint(x: contentRect.midX, y: contentRect.midY)

        cropFrame.size.width = ceil(cropFrame.width * scale)
        cropFrame.size.height = ceil(cropFrame.height * scale)
        cropFrame.origin.x = contentRect.origin.x + ceil((contentRect.width - cropFrame.width) * 0.5)
        cropFrame.origin.y = contentRect.origin.y + ceil((contentRect.height - cropFrame.height) * 0.5)

        let contentTargetPoint = CGPoint(x: (focusPoint.x + scrollView.contentOffset.x) * scale,
                                         y: (focusPoint.y + scrollView.contentOffset.y) * scale)

        var offset = CGPoint(x: -midPoint.x + contentTargetPoint.x,
                             y: -midPoint.y + contentTargetPoint.y)

        offset.x = max(-cropFrame.origin.x, offset.x)
        offset.y = max(-cropFrame.origin.y, offset.y)

        let translateBlock = {
            self.disableForegroundMatching = true
            if scale < 1.0 - .ulpOfOne || scale > 1.0 + .ulpOfOne {
                self.scrollView.zoomScale *= scale
                self.scrollView.zoomScale = min(self.scrollView.maximumZoomScale, self.scrollView.zoomScale)
            }

            if self.scrollView.zoomScale < self.scrollView.maximumZoomScale - .ulpOfOne {
                offset.x = min(-cropFrame.maxX + self.scrollView.contentSize.width, offset.x)
                offset.y = min(-cropFrame.maxY + self.scrollView.contentSize.height, offset.y)
                self.scrollView.contentOffset = offset
            }

            self.setCropBoxFrameInternal(cropFrame)
            self.disableForegroundMatching = false
            self.matchForegroundToBackground()
        }

        if !animated {
            translateBlock()
            return
        }

        matchForegroundToBackground()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.5,
                           delay: 0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 1.0,
                           options: .beginFromCurrentState,
                           animations: translateBlock,
                           completion: nil)
        }
    }

    public func setSimpleRenderMode(_ simpleMode: Bool, animated: Bool) {
        if simpleMode == self.simpleRenderMode { return }
        self.simpleRenderMode = simpleMode
        self.editing = false

        if !animated {
            toggleTranslucencyViewVisible(!simpleMode)
            return
        }

        UIView.animate(withDuration: 0.25) {
            self.toggleTranslucencyViewVisible(!simpleMode)
        }
    }

    public func setAspectRatio(_ aspectRatio: CGSize, animated: Bool) {
        self.aspectRatio = aspectRatio
        if !initialSetupPerformed { return }

        var zoomOut = false
        var targetAspect = aspectRatio
        if targetAspect.width < .ulpOfOne && targetAspect.height < .ulpOfOne {
            targetAspect = imageSize
            zoomOut = true
        }

        let boundsFrame = contentBounds
        var cropBoxFrame = self.cropBoxFrame
        var offset = scrollView.contentOffset

        let cropBoxIsPortrait: Bool
        if Int(targetAspect.width) == 1 && Int(targetAspect.height) == 1 {
            cropBoxIsPortrait = image.size.width > image.size.height
        } else {
            cropBoxIsPortrait = targetAspect.width < targetAspect.height
        }

        if cropBoxIsPortrait {
            let newWidth = floor(cropBoxFrame.height * (targetAspect.width / targetAspect.height))
            var delta = cropBoxFrame.width - newWidth
            cropBoxFrame.size.width = newWidth
            offset.x += delta * 0.5
            if delta < .ulpOfOne { cropBoxFrame.origin.x = contentBounds.origin.x }

            let boundsWidth = boundsFrame.width
            if newWidth > boundsWidth {
                let scale = boundsWidth / newWidth
                let newHeight = cropBoxFrame.height * scale
                delta = cropBoxFrame.height - newHeight
                cropBoxFrame.size.height = newHeight
                offset.y += delta * 0.5
                cropBoxFrame.size.width = boundsWidth
                zoomOut = true
            }
        } else {
            let newHeight = floor(cropBoxFrame.width * (targetAspect.height / targetAspect.width))
            var delta = cropBoxFrame.height - newHeight
            cropBoxFrame.size.height = newHeight
            offset.y += delta * 0.5
            if delta < .ulpOfOne { cropBoxFrame.origin.y = contentBounds.origin.y }

            let boundsHeight = boundsFrame.height
            if newHeight > boundsHeight {
                let scale = boundsHeight / newHeight
                let newWidth = cropBoxFrame.width * scale
                delta = cropBoxFrame.width - newWidth
                cropBoxFrame.size.width = newWidth
                offset.x += delta * 0.5
                cropBoxFrame.size.height = boundsHeight
                zoomOut = true
            }
        }

        cropBoxLastEditedSize = cropBoxFrame.size
        cropBoxLastEditedAngle = angle

        let translateBlock = {
            self.scrollView.contentOffset = offset
            self.setCropBoxFrameInternal(cropBoxFrame)
            if zoomOut { self.scrollView.zoomScale = self.scrollView.minimumZoomScale }
            self.moveCroppedContentToCenterAnimated(false)
            self.checkForCanReset()
        }

        if !animated {
            translateBlock(); return
        }

        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 1.0,
                       initialSpringVelocity: 0.7,
                       options: .beginFromCurrentState,
                       animations: translateBlock,
                       completion: nil)
    }

    public func rotateImageNinetyDegreesAnimated(_ animated: Bool, completion: ((Bool) -> Void)?) {
        rotateImageNinetyDegreesAnimated(animated, clockwise: false, completion: completion)
    }

    public func rotateImageNinetyDegreesAnimated(_ animated: Bool, clockwise: Bool, completion: ((Bool) -> Void)?) {
        if rotateAnimationInProgress { return }

        if resetTimer != nil {
            cancelResetTimer()
            setEditing(false, resetCropBox: true, animated: false)
            cropBoxLastEditedAngle = angle
            captureStateForImageRotation()
        }

        var newAngle = angle
        newAngle = clockwise ? newAngle + 90 : newAngle - 90
        if newAngle <= -360 || newAngle >= 360 { newAngle = 0 }
        internalAngle = newAngle

        var radians: CGFloat = 0
        switch newAngle {
        case 90: radians = .pi / 2
        case -90: radians = -.pi / 2
        case 180: radians = .pi
        case -180: radians = -.pi
        case 270: radians = .pi + .pi / 2
        case -270: radians = -(.pi + .pi / 2)
        default: break
        }

        let rotation = CGAffineTransform(rotationAngle: radians)

        let contentBounds = self.contentBounds
        let cropBoxFrame = self.cropBoxFrame
        let scale = min(contentBounds.width / cropBoxFrame.height, contentBounds.height / cropBoxFrame.width)

        let cropMidPoint = CGPoint(x: cropBoxFrame.midX, y: cropBoxFrame.midY)
        var cropTargetPoint = CGPoint(x: cropMidPoint.x + scrollView.contentOffset.x, y: cropMidPoint.y + scrollView.contentOffset.y)

        var newCropFrame = CGRect.zero
        if abs(angle) == abs(cropBoxLastEditedAngle) || (abs(angle) * -1) == ((abs(cropBoxLastEditedAngle) - 180) % 360) {
            newCropFrame.size = cropBoxLastEditedSize
            scrollView.minimumZoomScale = cropBoxLastEditedMinZoomScale
            scrollView.zoomScale = cropBoxLastEditedZoomScale
        } else {
            newCropFrame.size = CGSize(width: floor(cropBoxFrame.height * scale), height: floor(cropBoxFrame.width * scale))
            scrollView.minimumZoomScale *= scale
            scrollView.zoomScale *= scale
        }

        newCropFrame.origin.x = floor(contentBounds.midX - (newCropFrame.width * 0.5))
        newCropFrame.origin.y = floor(contentBounds.midY - (newCropFrame.height * 0.5))

        var snapshotView: UIView?
        if animated {
            snapshotView = foregroundContainerView.snapshotView(afterScreenUpdates: false)
            rotateAnimationInProgress = true
        }

        backgroundImageView.transform = rotation
        let containerSize = backgroundContainerView.frame.size
        backgroundContainerView.frame = CGRect(x: 0, y: 0, width: containerSize.height, height: containerSize.width)
        backgroundImageView.frame = CGRect(origin: .zero, size: backgroundImageView.frame.size)

        foregroundContainerView.transform = .identity
        foregroundImageView.transform = rotation

        scrollView.contentSize = backgroundContainerView.frame.size
        setCropBoxFrameInternal(newCropFrame)
        moveCroppedContentToCenterAnimated(false)
        newCropFrame = self.cropBoxFrame

        cropTargetPoint.x *= scale
        cropTargetPoint.y *= scale

        let swap = cropTargetPoint.x
        if clockwise {
            cropTargetPoint.x = scrollView.contentSize.width - cropTargetPoint.y
            cropTargetPoint.y = swap
        } else {
            cropTargetPoint.x = cropTargetPoint.y
            cropTargetPoint.y = scrollView.contentSize.height - swap
        }

        let midPoint = CGPoint(x: newCropFrame.midX, y: newCropFrame.midY)
        var offset = CGPoint(x: floor(-midPoint.x + cropTargetPoint.x), y: floor(-midPoint.y + cropTargetPoint.y))
        offset.x = max(-scrollView.contentInset.left, offset.x)
        offset.y = max(-scrollView.contentInset.top, offset.y)
        offset.x = min(scrollView.contentSize.width - (newCropFrame.width - scrollView.contentInset.right), offset.x)
        offset.y = min(scrollView.contentSize.height - (newCropFrame.height - scrollView.contentInset.bottom), offset.y)

        if offset.x == scrollView.contentOffset.x && offset.y == scrollView.contentOffset.y && scale == 1 {
            matchForegroundToBackground()
        }
        scrollView.contentOffset = offset

        if animated, let snapshotView {
            snapshotView.center = CGPoint(x: contentBounds.midX, y: contentBounds.midY)
            addSubview(snapshotView)

            backgroundContainerView.isHidden = true
            foregroundContainerView.isHidden = true
            translucencyView.isHidden = true
            gridOverlayView.isHidden = true

            UIView.animate(withDuration: 0.45,
                           delay: 0,
                           usingSpringWithDamping: 1.0,
                           initialSpringVelocity: 0.8,
                           options: .beginFromCurrentState,
                           animations: {
                var transform = CGAffineTransform(rotationAngle: clockwise ? .pi / 2 : -.pi / 2)
                transform = transform.scaledBy(x: scale, y: scale)
                snapshotView.transform = transform
            }, completion: { _ in
                self.backgroundContainerView.isHidden = false
                self.foregroundContainerView.isHidden = false
                self.translucencyView.isHidden = self.translucencyAlwaysHidden
                self.gridOverlayView.isHidden = false

                self.backgroundContainerView.alpha = 0.0
                self.gridOverlayView.alpha = 0.0
                self.translucencyView.alpha = 1.0

                UIView.animate(withDuration: 0.45, animations: {
                    snapshotView.alpha = 0.0
                    self.backgroundContainerView.alpha = 1.0
                    self.gridOverlayView.alpha = 1.0
                }, completion: { done in
                    self.rotateAnimationInProgress = false
                    snapshotView.removeFromSuperview()

                    let aspectRatioCanSwapDimensions = !self.aspectRatioLockEnabled || (self.aspectRatioLockEnabled && self.aspectRatioLockDimensionSwapEnabled)
                    if !aspectRatioCanSwapDimensions {
                        self.setAspectRatio(self.aspectRatio, animated: animated)
                    }
                    completion?(done)
                })
            })
        }

        checkForCanReset()
    }

    private func captureStateForImageRotation() {
        cropBoxLastEditedSize = cropBoxFrame.size
        cropBoxLastEditedZoomScale = scrollView.zoomScale
        cropBoxLastEditedMinZoomScale = scrollView.minimumZoomScale
    }

    private func checkForCanReset() {
        var canReset = false
        if angle != 0 {
            canReset = true
        } else if scrollView.zoomScale > scrollView.minimumZoomScale + .ulpOfOne {
            canReset = true
        } else if Int(floor(cropBoxFrame.width)) != Int(floor(originalCropBoxSize.width)) || Int(floor(cropBoxFrame.height)) != Int(floor(originalCropBoxSize.height)) {
            canReset = true
        } else if Int(floor(scrollView.contentOffset.x)) != Int(floor(originalContentOffset.x)) || Int(floor(scrollView.contentOffset.y)) != Int(floor(originalContentOffset.y)) {
            canReset = true
        }
        self.canBeReset = canReset
    }

    private func setCroppingViewsHiddenInternal(_ hidden: Bool, animated: Bool) {
        if internalCroppingViewsHidden == hidden { return }
        internalCroppingViewsHidden = hidden

        let alpha: CGFloat = hidden ? 0.0 : 1.0
        if !animated {
            backgroundImageView.alpha = alpha
            foregroundContainerView.alpha = alpha
            gridOverlayView.alpha = alpha
            toggleTranslucencyViewVisible(!hidden)
            return
        }

        foregroundContainerView.alpha = alpha
        backgroundImageView.alpha = alpha
        UIView.animate(withDuration: 0.4) {
            self.toggleTranslucencyViewVisible(!hidden)
            self.gridOverlayView.alpha = alpha
        }
    }

    private func setGridOverlayHiddenInternal(_ gridOverlayHidden: Bool, animated: Bool) {
        self.internalGridOverlayHidden = gridOverlayHidden
        gridOverlayView.alpha = gridOverlayHidden ? 1.0 : 0.0
        UIView.animate(withDuration: 0.4) {
            self.gridOverlayView.alpha = gridOverlayHidden ? 0.0 : 1.0
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        matchForegroundToBackground()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        startEditing(); canBeReset = true
    }

    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        startEditing(); canBeReset = true
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        startResetTimer(); checkForCanReset()
    }

    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        startResetTimer(); checkForCanReset()
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            cropBoxLastEditedZoomScale = scrollView.zoomScale
            cropBoxLastEditedMinZoomScale = scrollView.minimumZoomScale
        }
        matchForegroundToBackground()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { startResetTimer() }
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        backgroundContainerView
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == gridPanGestureRecognizer else { return true }
        let tapPoint = gestureRecognizer.location(in: self)
        let frame = gridOverlayView.frame
        let innerFrame = frame.insetBy(dx: 22.0, dy: 22.0)
        let outerFrame = frame.insetBy(dx: -22.0, dy: -22.0)
        if innerFrame.contains(tapPoint) || !outerFrame.contains(tapPoint) { return false }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gridPanGestureRecognizer?.state == .changed { return false }
        return true
    }

    public func setCroppingViewsHidden(_ hidden: Bool, animated: Bool) {
        setCroppingViewsHiddenInternal(hidden, animated: animated)
    }

    public func setGridOverlayHidden(_ hidden: Bool, animated: Bool) {
        setGridOverlayHiddenInternal(hidden, animated: animated)
    }

    public func setBackgroundImageViewHidden(_ hidden: Bool, animated: Bool) {
        if !animated {
            backgroundImageView.isHidden = hidden
            return
        }

        let beforeAlpha: CGFloat = hidden ? 1.0 : 0.0
        let targetAlpha: CGFloat = hidden ? 0.0 : 1.0

        backgroundImageView.isHidden = false
        backgroundImageView.alpha = beforeAlpha
        UIView.animate(withDuration: 0.5, animations: {
            self.backgroundImageView.alpha = targetAlpha
        }, completion: { completed in
            if completed && hidden {
                self.backgroundImageView.isHidden = true
            }
        })
    }
}
