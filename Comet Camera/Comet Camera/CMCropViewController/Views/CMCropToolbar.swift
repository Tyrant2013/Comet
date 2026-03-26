import UIKit

public final class CMCropToolbar: UIView {
    public var statusBarHeightInset: CGFloat = 0.0 { didSet { setNeedsLayout() } }
    public var backgroundViewOutsets: UIEdgeInsets = .zero { didSet { setNeedsLayout() } }

    public private(set) var doneTextButton: UIButton = UIButton(type: .system)
    public private(set) var doneIconButton: UIButton = UIButton(type: .system)

    public private(set) var cancelTextButton: UIButton = UIButton(type: .system)
    public private(set) var cancelIconButton: UIButton = UIButton(type: .system)

    public private(set) var rotateCounterclockwiseButton: UIButton = UIButton(type: .system)
    public private(set) var rotateClockwiseButton: UIButton? = UIButton(type: .system)
    public private(set) var resetButton: UIButton = UIButton(type: .system)
    public private(set) var clampButton: UIButton = UIButton(type: .system)
    public var rotateButton: UIButton { rotateCounterclockwiseButton }

    public var cancelButtonTapped: (() -> Void)?
    public var doneButtonTapped: (() -> Void)?
    public var rotateCounterclockwiseButtonTapped: (() -> Void)?
    public var rotateClockwiseButtonTapped: (() -> Void)?
    public var clampButtonTapped: (() -> Void)?
    public var resetButtonTapped: (() -> Void)?

    public var clampButtonGlowing: Bool = false {
        didSet {
            if oldValue == clampButtonGlowing { return }
            clampButton.tintColor = clampButtonGlowing ? nil : .white
        }
    }
    public var clampButtonFrame: CGRect { clampButton.frame }

    public var clampButtonHidden: Bool = false { didSet { if oldValue != clampButtonHidden { setNeedsLayout() } } }
    public var rotateCounterclockwiseButtonHidden: Bool = false { didSet { if oldValue != rotateCounterclockwiseButtonHidden { setNeedsLayout() } } }
    public var rotateClockwiseButtonHidden: Bool = false { didSet { if oldValue != rotateClockwiseButtonHidden { setNeedsLayout() } } }
    public var resetButtonHidden: Bool = false { didSet { if oldValue != resetButtonHidden { setNeedsLayout() } } }
    public var doneButtonHidden: Bool = false { didSet { if oldValue != doneButtonHidden { setNeedsLayout() } } }
    public var cancelButtonHidden: Bool = false { didSet { if oldValue != cancelButtonHidden { setNeedsLayout() } } }

    public var reverseContentLayout: Bool = false { didSet { if oldValue != reverseContentLayout { setNeedsLayout() } } }
    public var resetButtonEnabled: Bool {
        get { resetButton.isEnabled }
        set { resetButton.isEnabled = newValue }
    }
    public var doneButtonFrame: CGRect { doneIconButton.isHidden ? doneTextButton.frame : doneIconButton.frame }

    public var doneTextButtonTitle: String = "" {
        didSet {
            if oldValue == doneTextButtonTitle { return }
            doneTextButton.setTitle(doneTextButtonTitle, for: .normal)
            doneTextButton.sizeToFit()
        }
    }
    public var cancelTextButtonTitle: String = "" {
        didSet {
            if oldValue == cancelTextButtonTitle { return }
            cancelTextButton.setTitle(cancelTextButtonTitle, for: .normal)
            cancelTextButton.sizeToFit()
        }
    }

    public var doneButtonColor: UIColor? {
        didSet {
            let color = doneButtonColor ?? UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
            if oldValue === color { return }
            doneTextButton.setTitleColor(color, for: .normal)
            doneIconButton.tintColor = color
            doneTextButton.sizeToFit()
        }
    }

    public var cancelButtonColor: UIColor? {
        didSet {
            if oldValue === cancelButtonColor { return }
            cancelTextButton.setTitleColor(cancelButtonColor, for: .normal)
            cancelIconButton.tintColor = cancelButtonColor
            cancelTextButton.sizeToFit()
        }
    }

    public var showOnlyIcons: Bool = false {
        didSet {
            if oldValue == showOnlyIcons { return }
            doneIconButton.sizeToFit()
            cancelIconButton.sizeToFit()
            setNeedsLayout()
        }
    }

    public var disableRotationButtons: Bool = false {
        didSet {
            if oldValue == disableRotationButtons { return }
            rotateClockwiseButton?.isEnabled = !disableRotationButtons
            rotateCounterclockwiseButton.isEnabled = !disableRotationButtons
        }
    }

    public var visibleCancelButton: UIView {
        cancelIconButton.isHidden ? cancelTextButton : cancelIconButton
    }

    private let backgroundView = UIView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        addSubview(backgroundView)

        reverseContentLayout = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft

        let bundle = CM_CROP_VIEW_RESOURCE_BUNDLE_FOR_OBJECT(self)

        doneTextButtonTitle = NSLocalizedString("Done", tableName: "TOCropViewControllerLocalizable", bundle: bundle, value: "Done", comment: "")
        doneTextButton.setTitle(doneTextButtonTitle, for: .normal)
        doneTextButton.setTitleColor(UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0), for: .normal)
        if #available(iOS 13.0, *) {
            doneTextButton.titleLabel?.font = .systemFont(ofSize: 17.0, weight: .medium)
        } else {
            doneTextButton.titleLabel?.font = .systemFont(ofSize: 17.0)
        }
        doneTextButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        doneTextButton.sizeToFit()
        addSubview(doneTextButton)

        doneIconButton.setImage(Self.doneImage(), for: .normal)
        doneIconButton.tintColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        doneIconButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(doneIconButton)
        doneButtonColor = nil

        cancelTextButtonTitle = NSLocalizedString("Cancel", tableName: "TOCropViewControllerLocalizable", bundle: bundle, value: "Cancel", comment: "")
        cancelTextButton.setTitle(cancelTextButtonTitle, for: .normal)
        cancelTextButton.titleLabel?.font = .systemFont(ofSize: 17.0)
        cancelTextButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        cancelTextButton.sizeToFit()
        addSubview(cancelTextButton)

        cancelIconButton.setImage(Self.cancelImage(), for: .normal)
        cancelIconButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(cancelIconButton)

        clampButton.contentMode = .center
        clampButton.tintColor = .white
        clampButton.setImage(Self.clampImage(), for: .normal)
        clampButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(clampButton)

        rotateCounterclockwiseButton.contentMode = .center
        rotateCounterclockwiseButton.tintColor = .white
        rotateCounterclockwiseButton.setImage(Self.rotateCCWImage(), for: .normal)
        rotateCounterclockwiseButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(rotateCounterclockwiseButton)

        rotateClockwiseButton?.contentMode = .center
        rotateClockwiseButton?.tintColor = .white
        rotateClockwiseButton?.setImage(Self.rotateCWImage(), for: .normal)
        rotateClockwiseButton?.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        if let rotateClockwiseButton { addSubview(rotateClockwiseButton) }

        resetButton.contentMode = .center
        resetButton.tintColor = .white
        resetButton.isEnabled = false
        resetButton.setImage(Self.resetImage(), for: .normal)
        resetButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        resetButton.accessibilityLabel = NSLocalizedString("Reset", tableName: "TOCropViewControllerLocalizable", bundle: bundle, value: "Reset", comment: "")
        addSubview(resetButton)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let verticalLayout = bounds.width < bounds.height
        let boundsSize = bounds.size

        cancelIconButton.isHidden = cancelButtonHidden || (showOnlyIcons ? false : !verticalLayout)
        cancelTextButton.isHidden = cancelButtonHidden || (showOnlyIcons ? true : verticalLayout)
        doneIconButton.isHidden = doneButtonHidden || (showOnlyIcons ? false : !verticalLayout)
        doneTextButton.isHidden = doneButtonHidden || (showOnlyIcons ? true : verticalLayout)

        var backgroundFrame = bounds
        backgroundFrame.origin.x -= backgroundViewOutsets.left
        backgroundFrame.size.width += backgroundViewOutsets.left + backgroundViewOutsets.right
        backgroundFrame.origin.y -= backgroundViewOutsets.top
        backgroundFrame.size.height += backgroundViewOutsets.top + backgroundViewOutsets.bottom
        backgroundView.frame = backgroundFrame

        if !verticalLayout {
            let insetPadding: CGFloat = 10.0
            var frame = CGRect.zero
            frame.size.height = 44.0
            frame.size.width = showOnlyIcons ? 44.0 : min(self.frame.width / 3.0, cancelTextButton.frame.width)
            frame.origin.x = reverseContentLayout ? (boundsSize.width - (frame.width + insetPadding)) : insetPadding
            (showOnlyIcons ? cancelIconButton : cancelTextButton).frame = frame

            frame.size.width = showOnlyIcons ? 44.0 : min(self.frame.width / 3.0, doneTextButton.frame.width)
            frame.origin.x = reverseContentLayout ? insetPadding : (boundsSize.width - (frame.width + insetPadding))
            (showOnlyIcons ? doneIconButton : doneTextButton).frame = frame

            let leadingFrame = (showOnlyIcons ? cancelIconButton : cancelTextButton).frame
            let trailingFrame = (showOnlyIcons ? doneIconButton : doneTextButton).frame
            let x = reverseContentLayout ? trailingFrame.maxX : leadingFrame.maxX
            let width = reverseContentLayout ? (leadingFrame.minX - trailingFrame.maxX) : (trailingFrame.minX - leadingFrame.maxX)
            let containerRect = CGRect(x: x, y: frame.origin.y, width: width, height: 44.0).integral

            let buttonSize = CGSize(width: 44.0, height: 44.0)
            var buttons: [UIButton] = []
            if !rotateCounterclockwiseButtonHidden { buttons.append(rotateCounterclockwiseButton) }
            if !resetButtonHidden { buttons.append(resetButton) }
            if !clampButtonHidden { buttons.append(clampButton) }
            if !rotateClockwiseButtonHidden, let rotateClockwiseButton { buttons.append(rotateClockwiseButton) }
            layoutToolbarButtons(buttons, sameButtonSize: buttonSize, in: containerRect, horizontally: true)
        } else {
            var frame = CGRect.zero
            frame.size = CGSize(width: 44.0, height: 44.0)
            frame.origin.y = bounds.height - 44.0
            cancelIconButton.frame = frame

            frame.origin.y = statusBarHeightInset
            doneIconButton.frame = frame

            let containerRect = CGRect(x: 0, y: doneIconButton.frame.maxY, width: 44.0, height: cancelIconButton.frame.minY - doneIconButton.frame.maxY)
            let buttonSize = CGSize(width: 44.0, height: 44.0)
            var buttons: [UIButton] = []
            if !rotateCounterclockwiseButtonHidden { buttons.append(rotateCounterclockwiseButton) }
            if !resetButtonHidden { buttons.append(resetButton) }
            if !clampButtonHidden { buttons.append(clampButton) }
            if !rotateClockwiseButtonHidden, let rotateClockwiseButton { buttons.append(rotateClockwiseButton) }
            layoutToolbarButtons(buttons, sameButtonSize: buttonSize, in: containerRect, horizontally: false)
        }
    }

    private func layoutToolbarButtons(_ buttons: [UIButton], sameButtonSize size: CGSize, in containerRect: CGRect, horizontally: Bool) {
        guard !buttons.isEmpty else { return }
        let fixedSize: CGFloat = horizontally ? size.width : size.height
        let maxLength: CGFloat = horizontally ? containerRect.width : containerRect.height
        let padding = (maxLength - fixedSize * CGFloat(buttons.count)) / CGFloat(buttons.count + 1)

        for (index, button) in buttons.enumerated() {
            let sameOffset = horizontally ? abs(containerRect.height - 44.0) : abs(containerRect.width - size.width)
            let diffOffset = padding + CGFloat(index) * (fixedSize + padding)
            var origin = horizontally ? CGPoint(x: diffOffset, y: sameOffset) : CGPoint(x: sameOffset, y: diffOffset)
            if horizontally {
                origin.x += containerRect.minX
                if #available(iOS 15.0, *) {
                    var config = button.configuration ?? .plain()
                    config.imagePlacement = .leading
                    config.imagePadding = 8
                    if let image = button.imageView?.image {
                        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: image.baselineOffsetFromBottom ?? 0, trailing: 0)
                    }
                    button.configuration = config
                } else if #available(iOS 13.0, *) {
                    if let image = button.imageView?.image {
                        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: image.baselineOffsetFromBottom ?? 0, right: 0)
                    }
                }
            } else {
                origin.y += containerRect.minY
            }
            button.frame = CGRect(origin: origin, size: size)
        }
    }

    @objc private func buttonTapped(_ button: UIButton) {
        if button == cancelTextButton || button == cancelIconButton {
            cancelButtonTapped?()
            return
        }
        if button == doneTextButton || button == doneIconButton {
            doneButtonTapped?()
            return
        }
        if button == resetButton {
            resetButtonTapped?()
            return
        }
        if button == rotateCounterclockwiseButton {
            rotateCounterclockwiseButtonTapped?()
            return
        }
        if button == rotateClockwiseButton {
            rotateClockwiseButtonTapped?()
            return
        }
        if button == clampButton {
            clampButtonTapped?()
        }
    }

    private static func doneImage() -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "checkmark",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 17, height: 14))
        return renderer.image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 1, y: 7))
            path.addLine(to: CGPoint(x: 6, y: 12))
            path.addLine(to: CGPoint(x: 16, y: 1))
            UIColor.white.setStroke()
            path.lineWidth = 2
            path.stroke()
        }
    }

    private static func cancelImage() -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "xmark",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { _ in
            let p1 = UIBezierPath()
            p1.move(to: CGPoint(x: 15, y: 15))
            p1.addLine(to: CGPoint(x: 1, y: 1))
            UIColor.white.setStroke()
            p1.lineWidth = 2
            p1.stroke()

            let p2 = UIBezierPath()
            p2.move(to: CGPoint(x: 1, y: 15))
            p2.addLine(to: CGPoint(x: 15, y: 1))
            UIColor.white.setStroke()
            p2.lineWidth = 2
            p2.stroke()
        }
    }

    private static func rotateCCWImage() -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "rotate.left.fill",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 4)
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 21))
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 9, width: 12, height: 12)).fill()

            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: 5, y: 3))
            tri.addLine(to: CGPoint(x: 10, y: 6))
            tri.addLine(to: CGPoint(x: 10, y: 0))
            tri.close()
            tri.fill()

            let arc = UIBezierPath()
            arc.move(to: CGPoint(x: 10, y: 3))
            arc.addCurve(to: CGPoint(x: 17.5, y: 11),
                         controlPoint1: CGPoint(x: 15, y: 3),
                         controlPoint2: CGPoint(x: 17.5, y: 5.91))
            arc.lineWidth = 1
            arc.stroke()
        }
    }

    private static func rotateCWImage() -> UIImage? {
        guard let ccw = rotateCCWImage(), let cg = ccw.cgImage else { return nil }
        let renderer = UIGraphicsImageRenderer(size: ccw.size)
        return renderer.image { context in
            let cgctx = context.cgContext
            cgctx.translateBy(x: ccw.size.width, y: ccw.size.height)
            cgctx.rotate(by: .pi)
            cgctx.draw(cg, in: CGRect(origin: .zero, size: ccw.size))
        }
    }

    private static func resetImage() -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "arrow.counterclockwise",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 0)
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 22, height: 18))
        return renderer.image { _ in
            UIColor.white.setFill()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 22, y: 9))
            p.addCurve(to: CGPoint(x: 13, y: 18), controlPoint1: CGPoint(x: 22, y: 13.97), controlPoint2: CGPoint(x: 17.97, y: 18))
            p.addCurve(to: CGPoint(x: 13, y: 16), controlPoint1: CGPoint(x: 13, y: 17.35), controlPoint2: CGPoint(x: 13, y: 16.68))
            p.addCurve(to: CGPoint(x: 20, y: 9), controlPoint1: CGPoint(x: 16.87, y: 16), controlPoint2: CGPoint(x: 20, y: 12.87))
            p.addCurve(to: CGPoint(x: 13, y: 2), controlPoint1: CGPoint(x: 20, y: 5.13), controlPoint2: CGPoint(x: 16.87, y: 2))
            p.addCurve(to: CGPoint(x: 6.55, y: 6.27), controlPoint1: CGPoint(x: 10.1, y: 2), controlPoint2: CGPoint(x: 7.62, y: 3.76))
            p.addCurve(to: CGPoint(x: 6, y: 9), controlPoint1: CGPoint(x: 6.2, y: 7.11), controlPoint2: CGPoint(x: 6, y: 8.03))
            p.addLine(to: CGPoint(x: 4, y: 9))
            p.addCurve(to: CGPoint(x: 4.65, y: 5.63), controlPoint1: CGPoint(x: 4, y: 7.81), controlPoint2: CGPoint(x: 4.23, y: 6.67))
            p.addCurve(to: CGPoint(x: 7.65, y: 1.76), controlPoint1: CGPoint(x: 5.28, y: 4.08), controlPoint2: CGPoint(x: 6.32, y: 2.74))
            p.addCurve(to: CGPoint(x: 13, y: 0), controlPoint1: CGPoint(x: 9.15, y: 0.65), controlPoint2: CGPoint(x: 11, y: 0))
            p.addCurve(to: CGPoint(x: 22, y: 9), controlPoint1: CGPoint(x: 17.97, y: 0), controlPoint2: CGPoint(x: 22, y: 4.03))
            p.close()
            p.fill()

            let tri = UIBezierPath()
            tri.move(to: CGPoint(x: 5, y: 15))
            tri.addLine(to: CGPoint(x: 10, y: 9))
            tri.addLine(to: CGPoint(x: 0, y: 9))
            tri.close()
            tri.fill()
        }
    }

    private static func clampImage() -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: "aspectratio.fill",
                           withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withBaselineOffset(fromBottom: 0)
        }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 22, height: 16))
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 3, width: 13, height: 13)).fill()
            UIColor(white: 1.0, alpha: 0.553).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 22, height: 2)).fill()
            UIBezierPath(rect: CGRect(x: 19, y: 2, width: 3, height: 14)).fill()
            UIColor(white: 1.0, alpha: 0.773).setFill()
            UIBezierPath(rect: CGRect(x: 14, y: 3, width: 4, height: 13)).fill()
        }
    }
}
