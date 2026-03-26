import UIKit
private let kCMCropViewControllerTitleTopPadding: CGFloat = 14.0
private let kCMCropViewControllerToolbarHeight: CGFloat = 44.0

@MainActor @objc public protocol CMCropViewControllerDelegate: NSObjectProtocol {
    @objc optional func cropViewController(_ cropViewController: CMCropViewController, didCropImageToRect cropRect: CGRect, angle: Int)
    @objc optional func cropViewController(_ cropViewController: CMCropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int)
    @objc optional func cropViewController(_ cropViewController: CMCropViewController, didCropToCircularImage image: UIImage, withRect cropRect: CGRect, angle: Int)
    @objc optional func cropViewController(_ cropViewController: CMCropViewController, didFinishCancelled cancelled: Bool)
}

open class CMCropViewController: UIViewController, CMCropViewDelegate, UIViewControllerTransitioningDelegate {
    public private(set) var image: UIImage
    public var minimumAspectRatio: CGFloat = 0.0 {
        didSet { cropView.minimumAspectRatio = minimumAspectRatio }
    }

    public weak var delegate: (any CMCropViewControllerDelegate)?

    public var showActivitySheetOnDone: Bool = false

    public var imageCropFrame: CGRect {
        get { cropView.imageCropFrame }
        set { cropView.imageCropFrame = newValue }
    }

    public var angle: Int {
        get { cropView.angle }
        set { cropView.angle = normalizedAngle(newValue) }
    }

    public var croppingStyle: CMCropViewCroppingStyle { cropView.croppingStyle }

    private var internalAspectRatioPreset: CGSize = .zero
    public var aspectRatioPreset: CGSize {
        get { internalAspectRatioPreset }
        set { internalAspectRatioPreset = newValue }
    }

    public var titleLabel: UILabel? {
        guard let title, !title.isEmpty else { return nil }
        return internalTitleLabel
    }

    public var aspectRatioLockEnabled: Bool {
        get { cropView.aspectRatioLockEnabled }
        set {
            internalToolbar.clampButtonGlowing = newValue
            cropView.aspectRatioLockEnabled = newValue
            if !aspectRatioPickerButtonHidden {
                aspectRatioPickerButtonHidden = (newValue && !resetAspectRatioEnabled)
            }
        }
    }

    public var aspectRatioLockDimensionSwapEnabled: Bool {
        get { cropView.aspectRatioLockDimensionSwapEnabled }
        set { cropView.aspectRatioLockDimensionSwapEnabled = newValue }
    }

    public var resetAspectRatioEnabled: Bool {
        get { cropView.resetAspectRatioEnabled }
        set {
            cropView.resetAspectRatioEnabled = newValue
            if !aspectRatioPickerButtonHidden {
                aspectRatioPickerButtonHidden = (!newValue && aspectRatioLockEnabled)
            }
        }
    }

    public var toolbarPosition: CMCropViewControllerToolbarPosition = .bottom {
        didSet { view.setNeedsLayout() }
    }

    public var rotateClockwiseButtonHidden: Bool {
        get { toolbar.rotateClockwiseButtonHidden }
        set { toolbar.rotateClockwiseButtonHidden = newValue }
    }

    public var rotateButtonsHidden: Bool {
        get { toolbar.rotateCounterclockwiseButtonHidden && toolbar.rotateClockwiseButtonHidden }
        set {
            toolbar.rotateCounterclockwiseButtonHidden = newValue
            toolbar.rotateClockwiseButtonHidden = newValue
        }
    }

    public var resetButtonHidden: Bool {
        get { toolbar.resetButtonHidden }
        set { toolbar.resetButtonHidden = newValue }
    }

    public var aspectRatioPickerButtonHidden: Bool {
        get { toolbar.clampButtonHidden }
        set { toolbar.clampButtonHidden = newValue }
    }

    public var doneButtonHidden: Bool {
        get { toolbar.doneButtonHidden }
        set { toolbar.doneButtonHidden = newValue }
    }

    public var cancelButtonHidden: Bool {
        get { toolbar.cancelButtonHidden }
        set { toolbar.cancelButtonHidden = newValue }
    }

    public var activityItems: [Any]?
    public var applicationActivities: [UIActivity]?
    public var excludedActivityTypes: [UIActivity.ActivityType]?
    public var allowedAspectRatios: [CMCropViewControllerAspectRatioPreset]?

    public var onDidFinishCancelled: ((Bool) -> Void)?
    public var onDidCropImageToRect: ((CGRect, Int) -> Void)?
    public var onDidCropToRect: ((UIImage, CGRect, NSInteger) -> Void)?
    public var onDidCropToCircleImage: ((UIImage, CGRect, NSInteger) -> Void)?

    public var cropView: CMCropView { internalCropView }
    public var toolbar: CMCropToolbar { internalToolbar }

    public var hidesNavigationBar: Bool = true
    public var doneButtonTitle: String! {
        didSet { if doneButtonTitle != nil { toolbar.doneTextButtonTitle = doneButtonTitle } }
    }
    public var cancelButtonTitle: String! {
        didSet { if cancelButtonTitle != nil { toolbar.cancelTextButtonTitle = cancelButtonTitle } }
    }
    public var showOnlyIcons: Bool {
        get { toolbar.showOnlyIcons }
        set { toolbar.showOnlyIcons = newValue }
    }
    public var showCancelConfirmationDialog: Bool = false
    public var doneButtonColor: UIColor? {
        get { toolbar.doneButtonColor }
        set { toolbar.doneButtonColor = newValue }
    }
    public var cancelButtonColor: UIColor? {
        get { toolbar.cancelButtonColor }
        set { toolbar.cancelButtonColor = newValue }
    }
    public var reverseContentLayout: Bool {
        get { toolbar.reverseContentLayout }
        set { toolbar.reverseContentLayout = newValue }
    }

    private let internalCropView: CMCropView
    private let internalToolbar = CMCropToolbar()
    private let internalTitleLabel = UILabel()
    private let customTransitioning = CMCropViewControllerTransitioning()
    private var toolbarSnapshotView: UIView?
    private var prepareForTransitionHandler: (() -> Void)?

    private var firstTime = false
    private var inTransition = false
    private var navigationBarHidden = false
    private var navToolbarHidden = false
    private var currentAspectRatioIndex = 0

    open override var childForStatusBarStyle: UIViewController? { nil }
    open override var childForStatusBarHidden: UIViewController? { nil }
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        if navigationController != nil {
            return .lightContent
        }
        if #available(iOS 13.0, *) {
            return .darkContent
        }
        return .default
    }
    open override var prefersStatusBarHidden: Bool {
        if !overrideStatusBar {
            return statusBarHidden
        }
        var hidden = true
        hidden = hidden && !inTransition
        hidden = hidden && (view.superview != nil)
        return hidden
    }
    open override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    private var overrideStatusBar: Bool {
        if navigationController != nil { return false }
        if presentingViewController?.prefersStatusBarHidden == true { return false }
        return true
    }

    private var statusBarHidden: Bool {
        if let nav = navigationController {
            return nav.prefersStatusBarHidden
        }
        if presentingViewController?.prefersStatusBarHidden == true {
            return true
        }
        return true
    }

    private var statusBarHeight: CGFloat {
        var inset = view.safeAreaInsets.top
        var hardwareRelatedInset = view.safeAreaInsets.bottom > .ulpOfOne && UIDevice.current.userInterfaceIdiom == .phone
#if targetEnvironment(macCatalyst)
        hardwareRelatedInset = true
#endif
        if statusBarHidden && !hardwareRelatedInset {
            inset = 0.0
        }
        return inset
    }

    private var statusBarSafeInsets: UIEdgeInsets {
        var insets = view.safeAreaInsets
        insets.top = statusBarHeight
        return insets
    }

    public init(image: UIImage) {
        self.image = image
        self.internalCropView = CMCropView(image: image)
        super.init(nibName: nil, bundle: nil)
        setUpController()
    }

    public init(croppingStyle: CMCropViewCroppingStyle, image: UIImage) {
        self.image = image
        self.internalCropView = CMCropView(croppingStyle: croppingStyle, image: image)
        super.init(nibName: nil, bundle: nil)
        setUpController()
    }

    public required init?(coder: NSCoder) {
        nil
    }

    private func setUpController() {
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .fullScreen
        transitioningDelegate = self
        internalCropView.delegate = self
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = internalCropView.backgroundColor
        view.addSubview(internalCropView)
        view.addSubview(internalToolbar)

        internalTitleLabel.textColor = .white
        internalTitleLabel.textAlignment = .center
        internalTitleLabel.font = .systemFont(ofSize: 17.0, weight: .semibold)

        let circularMode = croppingStyle == .circular
        internalCropView.frame = frameForCropView(verticalLayout: verticalLayout)
        internalToolbar.frame = frameForToolbar(verticalLayout: verticalLayout)
        internalToolbar.clampButtonHidden = aspectRatioPickerButtonHidden || circularMode
        internalToolbar.rotateClockwiseButtonHidden = rotateClockwiseButtonHidden

        wireToolbarActions()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if animated {
            inTransition = true
            setNeedsStatusBarAppearanceUpdate()
        }

        if let navigationController {
            if hidesNavigationBar {
                navigationBarHidden = navigationController.isNavigationBarHidden
                navToolbarHidden = navigationController.isToolbarHidden
                navigationController.setNavigationBarHidden(true, animated: animated)
                navigationController.setToolbarHidden(true, animated: animated)
            }
            modalTransitionStyle = .coverVertical
        } else {
            internalCropView.setBackgroundImageViewHidden(true, animated: false)
            internalTitleLabel.alpha = animated ? 0.0 : 1.0
        }

        if !aspectRatioPreset.equalTo(.zero) {
            setAspectRatioPreset(aspectRatioPreset, animated: false)
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inTransition = false
        internalCropView.simpleRenderMode = false

        let updateContentBlock = {
            self.setNeedsStatusBarAppearanceUpdate()
            self.internalTitleLabel.alpha = 1.0
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: updateContentBlock)
        } else {
            updateContentBlock()
        }

        if internalCropView.gridOverlayHidden {
            internalCropView.setGridOverlayHidden(false, animated: animated)
        }

        if navigationController == nil {
            internalCropView.setBackgroundImageViewHidden(false, animated: animated)
        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        inTransition = true
        UIView.animate(withDuration: 0.5) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
        if let navigationController, hidesNavigationBar {
            navigationController.setNavigationBarHidden(navigationBarHidden, animated: animated)
            navigationController.setToolbarHidden(navToolbarHidden, animated: animated)
        }
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        inTransition = false
        setNeedsStatusBarAppearanceUpdate()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let verticalLayout = self.verticalLayout
        UIView.performWithoutAnimation {
            internalToolbar.frame = frameForToolbar(verticalLayout: verticalLayout)
            adjustToolbarInsets()
            internalToolbar.setNeedsLayout()
        }
        internalCropView.frame = frameForCropView(verticalLayout: verticalLayout)
        adjustCropViewInsets()
        internalCropView.moveCroppedContentToCenterAnimated(false)
        if !firstTime {
            internalCropView.performInitialSetup()
            firstTime = true
        }

        if let text = title, !text.isEmpty {
            internalTitleLabel.frame = frameForTitleLabel(size: internalTitleLabel.frame.size, verticalLayout: verticalLayout)
            internalCropView.moveCroppedContentToCenterAnimated(false)
        }

        internalCropView.minimumAspectRatio = minimumAspectRatio
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if size.equalTo(view.bounds.size) { return }

        let orientation: UIInterfaceOrientation
#if os(visionOS)
        orientation = .landscapeLeft
#else
        let currentSize = view.bounds.size
        orientation = currentSize.width < size.width ? .landscapeLeft : .portrait
#endif

        performWillRotate(to: orientation, duration: coordinator.transitionDuration)
        coordinator.animate(alongsideTransition: { _ in
            self.performWillAnimateRotation(to: orientation, duration: coordinator.transitionDuration)
        }, completion: { _ in
            self.performDidRotate(from: orientation)
        })
    }

    private func wireToolbarActions() {
        internalToolbar.cancelButtonTapped = { [weak self] in self?.cancelTapped() }
        internalToolbar.doneButtonTapped = { [weak self] in self?.commitCurrentCrop() }
        internalToolbar.rotateCounterclockwiseButtonTapped = { [weak self] in self?.rotateCropViewCounterclockwise() }
        internalToolbar.rotateClockwiseButtonTapped = { [weak self] in self?.rotateCropViewClockwise() }
        internalToolbar.resetButtonTapped = { [weak self] in self?.resetCropViewLayout() }
        internalToolbar.clampButtonTapped = { [weak self] in self?.showAspectRatioDialog() }
    }

    private var verticalLayout: Bool {
        view.bounds.width < view.bounds.height
    }

    private func frameForToolbar(verticalLayout: Bool) -> CGRect {
        let insets = statusBarSafeInsets
        if !verticalLayout {
            return CGRect(x: insets.left, y: 0.0, width: kCMCropViewControllerToolbarHeight, height: view.frame.height)
        }

        var frame = CGRect.zero
        frame.size.width = view.bounds.width
        frame.size.height = kCMCropViewControllerToolbarHeight
        if toolbarPosition == .bottom {
            frame.origin.y = view.bounds.height - (frame.height + insets.bottom)
        } else {
            frame.origin.y = insets.top
        }
        return frame
    }

    private func frameForCropView(verticalLayout: Bool) -> CGRect {
        let bounds = view.bounds
        var frame = CGRect.zero
        if !verticalLayout {
            frame.origin.x = internalToolbar.frame.maxX
            frame.size.width = bounds.width - frame.origin.x
            frame.size.height = bounds.height
        } else {
            frame.size.width = bounds.width
            if toolbarPosition == .top {
                frame.origin.y = internalToolbar.frame.maxY
                frame.size.height = bounds.height - frame.origin.y
            } else {
                frame.size.height = internalToolbar.frame.minY
            }
        }
        return frame
    }

    private func frameForTitleLabel(size: CGSize, verticalLayout: Bool) -> CGRect {
        var frame = CGRect(origin: .zero, size: size)
        var viewWidth = view.bounds.width
        var x: CGFloat = 0.0
        if !verticalLayout {
            x = kCMCropViewControllerTitleTopPadding + view.safeAreaInsets.left
            viewWidth -= x
        }
        frame.origin.x = ceil((viewWidth - frame.width) * 0.5)
        if !verticalLayout { frame.origin.x += x }
        frame.origin.y = view.safeAreaInsets.top + kCMCropViewControllerTitleTopPadding
        return frame
    }

    private func adjustCropViewInsets() {
        var insets = statusBarSafeInsets
        if !verticalLayout {
            insets.left = 0.0
        } else if toolbarPosition == .top {
            insets.top = 0.0
        } else {
            insets.bottom = 0.0
        }

        if !verticalLayout || toolbarPosition == .bottom {
            if let text = title, !text.isEmpty {
                internalTitleLabel.text = text
                internalTitleLabel.sizeToFit()
                insets.top += internalTitleLabel.frame.height + kCMCropViewControllerTitleTopPadding
            }
        }
        internalCropView.cropRegionInsets = insets
    }

    private func adjustToolbarInsets() {
        var insets = UIEdgeInsets.zero
        if !verticalLayout {
            insets.left = view.safeAreaInsets.left
        } else if toolbarPosition == .top {
            insets.top = view.safeAreaInsets.top
        } else {
            insets.bottom = view.safeAreaInsets.bottom
        }
        internalToolbar.backgroundViewOutsets = insets
        internalToolbar.statusBarHeightInset = statusBarHeight
        internalToolbar.setNeedsLayout()
    }

    public override var title: String? {
        didSet {
            guard let title, !title.isEmpty else {
                internalTitleLabel.removeFromSuperview()
                internalCropView.cropRegionInsets = .zero
                return
            }
            if internalTitleLabel.superview == nil {
                view.insertSubview(internalTitleLabel, aboveSubview: internalToolbar)
            }
            internalTitleLabel.text = title
            internalTitleLabel.sizeToFit()
            internalTitleLabel.frame = frameForTitleLabel(size: internalTitleLabel.frame.size, verticalLayout: verticalLayout)
        }
    }

    private func rotateCropViewClockwise() {
        internalToolbar.disableRotationButtons = true
        internalCropView.rotateImageNinetyDegreesAnimated(true, clockwise: true) { _ in
            self.internalToolbar.disableRotationButtons = false
        }
    }

    private func rotateCropViewCounterclockwise() {
        internalToolbar.disableRotationButtons = true
        internalCropView.rotateImageNinetyDegreesAnimated(true, clockwise: false) { _ in
            self.internalToolbar.disableRotationButtons = false
        }
    }

    private func showAspectRatioDialog() {
        if internalCropView.aspectRatioLockEnabled {
            internalCropView.aspectRatioLockEnabled = false
            internalToolbar.clampButtonGlowing = false
            return
        }
        let presets = allowedAspectRatios ?? (internalCropView.cropBoxAspectRatioIsPortrait ? CMCropViewControllerAspectRatioPreset.portraitPresets() : CMCropViewControllerAspectRatioPreset.landscapePresets())
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        for preset in presets {
            alert.addAction(UIAlertAction(title: preset.title, style: .default, handler: { _ in
                self.setAspectRatioPreset(preset.size, animated: true)
                self.aspectRatioLockEnabled = true
            }))
        }
        alert.modalPresentationStyle = .popover
        alert.popoverPresentationController?.sourceView = internalToolbar
        alert.popoverPresentationController?.sourceRect = internalToolbar.clampButtonFrame
        present(alert, animated: true)
    }

    public func commitCurrentCrop() {
        doneButtonTapped()
    }

    private func doneButtonTapped() {
        let cropRect = internalCropView.imageCropFrame
        let angle = internalCropView.angle
        let circular = croppingStyle == .circular

        if showActivitySheetOnDone {
            let provider = CMActivityCroppedImageProvider(image: image, cropFrame: cropRect, angle: angle, circular: circular)
            let attributes = CMCroppedImageAttributes(croppedFrame: cropRect, angle: angle, originalImageSize: image.size)
            var items: [Any] = [provider, attributes]
            if let activityItems { items.append(contentsOf: activityItems) }
            let controller = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
            controller.excludedActivityTypes = excludedActivityTypes
            controller.modalPresentationStyle = .popover
            controller.popoverPresentationController?.sourceView = internalToolbar
            controller.popoverPresentationController?.sourceRect = internalToolbar.doneButtonFrame
            controller.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                guard completed else { return }
                guard let self else { return }
                var handled = false
                if self.onDidFinishCancelled != nil {
                    self.onDidFinishCancelled?(false)
                    handled = true
                }
                if self.delegate?.responds(to: #selector(CMCropViewControllerDelegate.cropViewController(_:didFinishCancelled:))) == true {
                    self.delegate?.cropViewController?(self, didFinishCancelled: false)
                    handled = true
                }
                if !handled {
                    if let nav = self.navigationController, nav.viewControllers.count > 1 {
                        nav.popViewController(animated: true)
                    } else {
                        self.presentingViewController?.dismiss(animated: true)
                    }
                }
            }
            present(controller, animated: true)
            return
        }
        internalToolbar.doneTextButton.isEnabled = false
        var handled = false
        if delegate?.responds(to: #selector(CMCropViewControllerDelegate.cropViewController(_:didCropImageToRect:angle:))) == true {
            delegate?.cropViewController?(self, didCropImageToRect: cropRect, angle: angle)
            handled = true
        }
        if onDidCropImageToRect != nil {
            onDidCropImageToRect?(cropRect, angle)
            handled = true
        }

        let circularDelegate = delegate?.responds(to: #selector(CMCropViewControllerDelegate.cropViewController(_:didCropToCircularImage:withRect:angle:))) == true
        let circularCallback = onDidCropToCircleImage != nil
        let imageDelegate = delegate?.responds(to: #selector(CMCropViewControllerDelegate.cropViewController(_:didCropToImage:withRect:angle:))) == true
        let imageCallback = onDidCropToRect != nil

        if circular && (circularDelegate || circularCallback) {
            let result = image.cm_croppedImage(frame: cropRect, angle: angle, circularClip: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                if circularDelegate { self.delegate?.cropViewController?(self, didCropToCircularImage: result, withRect: cropRect, angle: angle) }
                if circularCallback { self.onDidCropToCircleImage?(result, cropRect, angle) }
            }
            handled = true
        } else if imageDelegate || imageCallback {
            let result: UIImage = (angle == 0 && cropRect.equalTo(CGRect(origin: .zero, size: image.size)))
                ? image
                : image.cm_croppedImage(frame: cropRect, angle: angle, circularClip: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                if imageDelegate { self.delegate?.cropViewController?(self, didCropToImage: result, withRect: cropRect, angle: angle) }
                if imageCallback { self.onDidCropToRect?(result, cropRect, angle) }
            }
            handled = true
        }
        if !handled {
            presentingViewController?.dismiss(animated: true)
        }
    }

    public func resetCropViewLayout() {
        let animated = internalCropView.angle == 0
        if resetAspectRatioEnabled { aspectRatioLockEnabled = false }
        internalCropView.resetLayoutToDefaultAnimated(animated)
    }

    public func setAspectRatioPreset(_ aspectRatio: CGSize, animated: Bool) {
        internalAspectRatioPreset = aspectRatio
        internalCropView.setAspectRatio(aspectRatio, animated: animated)
    }

    public func presentAnimatedFrom(_ viewController: UIViewController, fromView view: UIView?, fromFrame frame: CGRect,
                                    setup: (() -> Void)?, completion: (() -> Void)?) {
        presentAnimatedFrom(viewController, fromImage: nil, fromView: view, fromFrame: frame, angle: 0, toImageFrame: .zero, setup: setup, completion: completion)
    }

    public func presentAnimatedFrom(_ viewController: UIViewController, fromImage image: UIImage?,
                                    fromView: UIView?, fromFrame: CGRect, angle: Int, toImageFrame toFrame: CGRect,
                                    setup: (() -> Void)?, completion: (() -> Void)?) {
        if self.angle != 0 || !toFrame.isEmpty {
            self.angle = angle
            imageCropFrame = toFrame
        }
        customTransitioning.isDismissing = false
        customTransitioning.image = image ?? self.image
        customTransitioning.fromView = fromView
        customTransitioning.fromFrame = fromFrame
        prepareForTransitionHandler = setup
        viewController.present(parent ?? self, animated: true) {
            completion?()
            self.internalCropView.setCroppingViewsHidden(false, animated: true)
            if !fromFrame.isEmpty {
                self.internalCropView.setGridOverlayHidden(false, animated: true)
            }
        }
    }

    public func dismissAnimatedFrom(_ viewController: UIViewController, toView: UIView?, toFrame: CGRect,
                                    setup: (() -> Void)?, completion: (() -> Void)?) {
        dismissAnimatedFrom(viewController, withCroppedImage: nil, toView: toView, toFrame: toFrame, setup: setup, completion: completion)
    }

    public func dismissAnimatedFrom(_ viewController: UIViewController, withCroppedImage croppedImage: UIImage?, toView: UIView?,
                                    toFrame: CGRect, setup: (() -> Void)?, completion: (() -> Void)?) {
        customTransitioning.isDismissing = true
        if let croppedImage {
            customTransitioning.image = croppedImage
            customTransitioning.fromFrame = internalCropView.convert(internalCropView.cropBoxFrame, to: view)
        } else {
            customTransitioning.image = image
            customTransitioning.fromFrame = internalCropView.convert(internalCropView.imageViewFrame, to: view)
        }
        customTransitioning.toView = toView
        customTransitioning.toFrame = toFrame
        prepareForTransitionHandler = setup
        viewController.dismiss(animated: true, completion: completion)
    }

    private func cancelTapped() {
        if !showCancelConfirmationDialog {
            dismissCropViewController()
            return
        }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = internalToolbar.visibleCancelButton
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete Changes", comment: ""), style: .destructive, handler: { _ in
            self.dismissCropViewController()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    private func dismissCropViewController() {
        var handled = false
        if delegate?.responds(to: #selector(CMCropViewControllerDelegate.cropViewController(_:didFinishCancelled:))) == true {
            delegate?.cropViewController?(self, didFinishCancelled: true)
            handled = true
        }
        if onDidFinishCancelled != nil {
            onDidFinishCancelled?(true)
            handled = true
        }
        if !handled {
            if let nav = navigationController, nav.viewControllers.count > 1 {
                nav.popViewController(animated: true)
            } else {
                presentingViewController?.dismiss(animated: true)
            }
        }
    }

    public func cropViewDidBecomeResettable(_ cropView: CMCropView) {
        internalToolbar.resetButtonEnabled = true
    }

    public func cropViewDidBecomeNonResettable(_ cropView: CMCropView) {
        internalToolbar.resetButtonEnabled = false
    }

    public override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        adjustCropViewInsets()
        adjustToolbarInsets()
    }

    private func normalizedAngle(_ angle: Int) -> Int {
        let normalized = angle % 360
        return normalized >= 0 ? normalized : normalized + 360
    }

    private func performWillRotate(to orientation: UIInterfaceOrientation, duration: TimeInterval) {
        let snapshot = internalToolbar.snapshotView(afterScreenUpdates: false)
        snapshot?.frame = internalToolbar.frame
        if orientation.isLandscape {
            snapshot?.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        } else {
            snapshot?.autoresizingMask = [.flexibleHeight, .flexibleRightMargin]
        }
        if let snapshot {
            view.addSubview(snapshot)
        }
        toolbarSnapshotView = snapshot

        var frame = frameForToolbar(verticalLayout: orientation.isPortrait)
        if orientation.isLandscape {
            frame.origin.x = -frame.size.width
        } else {
            frame.origin.y = view.bounds.size.height
        }
        internalToolbar.frame = frame
        internalToolbar.layoutIfNeeded()
        internalToolbar.alpha = 0.0

        internalCropView.prepareforRotation()
        internalCropView.frame = frameForCropView(verticalLayout: !orientation.isPortrait)
        internalCropView.simpleRenderMode = true
        internalCropView.internalLayoutDisabled = true
    }

    private func performWillAnimateRotation(to orientation: UIInterfaceOrientation, duration: TimeInterval) {
        internalToolbar.frame = frameForToolbar(verticalLayout: !orientation.isLandscape)
        internalToolbar.layer.removeAllAnimations()
        internalToolbar.layer.sublayers?.forEach { $0.removeAllAnimations() }

        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       options: .beginFromCurrentState,
                       animations: {
            self.internalCropView.frame = self.frameForCropView(verticalLayout: !orientation.isLandscape)
            self.internalToolbar.frame = self.frameForToolbar(verticalLayout: orientation.isPortrait)
            self.internalCropView.performRelayoutForRotation()
        })

        toolbarSnapshotView?.alpha = 0.0
        internalToolbar.alpha = 1.0
    }

    private func performDidRotate(from _: UIInterfaceOrientation) {
        toolbarSnapshotView?.removeFromSuperview()
        toolbarSnapshotView = nil
        internalCropView.setSimpleRenderMode(false, animated: true)
        internalCropView.internalLayoutDisabled = false
    }

    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if navigationController != nil || modalTransitionStyle == .coverVertical {
            return nil
        }

        internalCropView.simpleRenderMode = true
        customTransitioning.isDismissing = false
        customTransitioning.prepareForTransitionHandler = { [weak self] in
            guard let self else { return }
            customTransitioning.toFrame = self.internalCropView.convert(self.internalCropView.cropBoxFrame, to: self.view)
            if !customTransitioning.fromFrame.isEmpty || customTransitioning.fromView != nil {
                self.internalCropView.croppingViewsHidden = true
            }
            self.prepareForTransitionHandler?()
            self.prepareForTransitionHandler = nil
        }
        return customTransitioning
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if navigationController != nil || modalTransitionStyle == .coverVertical {
            return nil
        }

        customTransitioning.isDismissing = true
        customTransitioning.prepareForTransitionHandler = { [weak self] in
            guard let self else { return }
            if !self.customTransitioning.toFrame.isEmpty || self.customTransitioning.toView != nil {
                self.internalCropView.croppingViewsHidden = true
            } else {
                self.internalCropView.simpleRenderMode = true
            }
            self.prepareForTransitionHandler?()
        }
        return customTransitioning
    }
}
