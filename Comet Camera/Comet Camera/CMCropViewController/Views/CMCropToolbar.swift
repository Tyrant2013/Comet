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

        doneTextButtonTitle = "完成"
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

        doneIconButton.setImage(.doneImage, for: .normal)
        doneIconButton.tintColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        doneIconButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(doneIconButton)
        doneButtonColor = nil

        cancelTextButtonTitle = "取消"
        cancelTextButton.setTitle(cancelTextButtonTitle, for: .normal)
        cancelTextButton.titleLabel?.font = .systemFont(ofSize: 17.0)
        cancelTextButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        cancelTextButton.sizeToFit()
        addSubview(cancelTextButton)

        cancelIconButton.setImage(.cancelImage, for: .normal)
        cancelIconButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(cancelIconButton)

        clampButton.contentMode = .center
        clampButton.tintColor = .white
        clampButton.setImage(.clampImage, for: .normal)
        clampButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(clampButton)

        rotateCounterclockwiseButton.contentMode = .center
        rotateCounterclockwiseButton.tintColor = .white
        rotateCounterclockwiseButton.setImage(.rotateCCWImage, for: .normal)
        rotateCounterclockwiseButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        addSubview(rotateCounterclockwiseButton)

        rotateClockwiseButton?.contentMode = .center
        rotateClockwiseButton?.tintColor = .white
        rotateClockwiseButton?.setImage(.rotateCWImage, for: .normal)
        rotateClockwiseButton?.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        if let rotateClockwiseButton { addSubview(rotateClockwiseButton) }

        resetButton.contentMode = .center
        resetButton.tintColor = .white
        resetButton.isEnabled = false
        resetButton.setImage(.resetImage, for: .normal)
        resetButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        resetButton.accessibilityLabel = "重置"
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
                var config = button.configuration ?? .plain()
                config.imagePlacement = .leading
                config.imagePadding = 8
                if let image = button.imageView?.image {
                    config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: image.baselineOffsetFromBottom ?? 0, trailing: 0)
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
}
