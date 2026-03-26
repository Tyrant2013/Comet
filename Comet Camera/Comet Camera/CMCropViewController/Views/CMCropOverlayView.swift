import UIKit

private let kCMCropOverlayCornerWidth: CGFloat = 20.0

public final class CMCropOverlayView: UIView {
    private var horizontalGridLines: [UIView] = []
    private var verticalGridLines: [UIView] = []

    private var outerLineViews: [UIView] = [] // top, right, bottom, left
    private var topLeftLineViews: [UIView] = [] // vertical, horizontal
    private var bottomLeftLineViews: [UIView] = []
    private var bottomRightLineViews: [UIView] = []
    private var topRightLineViews: [UIView] = []

    private var internalGridHidden = false
    public var gridHidden: Bool {
        get { internalGridHidden }
        set { setGridHidden(newValue, animated: false) }
    }

    public var displayHorizontalGridLines: Bool = false {
        didSet {
            horizontalGridLines.forEach { $0.removeFromSuperview() }
            horizontalGridLines = displayHorizontalGridLines ? [createNewLineView(), createNewLineView()] : []
            setNeedsDisplay()
        }
    }

    public var displayVerticalGridLines: Bool = false {
        didSet {
            verticalGridLines.forEach { $0.removeFromSuperview() }
            verticalGridLines = displayVerticalGridLines ? [createNewLineView(), createNewLineView()] : []
            setNeedsDisplay()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        setup()
    }

    public required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        let newLineView: () -> UIView = { self.createNewLineView() }
        outerLineViews = [newLineView(), newLineView(), newLineView(), newLineView()]
        topLeftLineViews = [newLineView(), newLineView()]
        bottomLeftLineViews = [newLineView(), newLineView()]
        topRightLineViews = [newLineView(), newLineView()]
        bottomRightLineViews = [newLineView(), newLineView()]

        displayHorizontalGridLines = true
        displayVerticalGridLines = true
    }

    public override var frame: CGRect {
        didSet {
            if !outerLineViews.isEmpty {
                layoutLines()
            }
        }
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if !outerLineViews.isEmpty {
            layoutLines()
        }
    }

    private func layoutLines() {
        let boundsSize = bounds.size

        // Border lines
        for i in 0..<4 {
            let lineView = outerLineViews[i]
            let frame: CGRect
            switch i {
            case 0:
                frame = CGRect(x: -1.0, y: -1.0, width: boundsSize.width + 2.0, height: 1.0) // top
            case 1:
                frame = CGRect(x: boundsSize.width, y: 0.0, width: 1.0, height: boundsSize.height) // right
            case 2:
                frame = CGRect(x: -1.0, y: boundsSize.height, width: boundsSize.width + 2.0, height: 1.0) // bottom
            default:
                frame = CGRect(x: -1.0, y: 0.0, width: 1.0, height: boundsSize.height + 1.0) // left
            }
            lineView.frame = frame
        }

        // Corner lines
        let cornerLines = [topLeftLineViews, topRightLineViews, bottomRightLineViews, bottomLeftLineViews]
        for i in 0..<4 {
            let cornerLine = cornerLines[i]
            let verticalFrame: CGRect
            let horizontalFrame: CGRect
            switch i {
            case 0: // top left
                verticalFrame = CGRect(x: -3.0, y: -3.0, width: 3.0, height: kCMCropOverlayCornerWidth + 3.0)
                horizontalFrame = CGRect(x: 0.0, y: -3.0, width: kCMCropOverlayCornerWidth, height: 3.0)
            case 1: // top right
                verticalFrame = CGRect(x: boundsSize.width, y: -3.0, width: 3.0, height: kCMCropOverlayCornerWidth + 3.0)
                horizontalFrame = CGRect(x: boundsSize.width - kCMCropOverlayCornerWidth, y: -3.0, width: kCMCropOverlayCornerWidth, height: 3.0)
            case 2: // bottom right
                verticalFrame = CGRect(x: boundsSize.width, y: boundsSize.height - kCMCropOverlayCornerWidth, width: 3.0, height: kCMCropOverlayCornerWidth + 3.0)
                horizontalFrame = CGRect(x: boundsSize.width - kCMCropOverlayCornerWidth, y: boundsSize.height, width: kCMCropOverlayCornerWidth, height: 3.0)
            default: // bottom left
                verticalFrame = CGRect(x: -3.0, y: boundsSize.height - kCMCropOverlayCornerWidth, width: 3.0, height: kCMCropOverlayCornerWidth)
                horizontalFrame = CGRect(x: -3.0, y: boundsSize.height, width: kCMCropOverlayCornerWidth + 3.0, height: 3.0)
            }

            cornerLine[0].frame = verticalFrame
            cornerLine[1].frame = horizontalFrame
        }

        // Horizontal grid lines
        let thickness = 1.0 / traitCollection.displayScale
        var numberOfLines = horizontalGridLines.count
        var padding = (bounds.height - (thickness * CGFloat(numberOfLines))) / CGFloat(numberOfLines + 1)
        for i in 0..<numberOfLines {
            let lineView = horizontalGridLines[i]
            var frame = CGRect.zero
            frame.size.height = thickness
            frame.size.width = bounds.width
            frame.origin.y = (padding * CGFloat(i + 1)) + (thickness * CGFloat(i))
            lineView.frame = frame
        }

        // Vertical grid lines
        numberOfLines = verticalGridLines.count
        padding = (bounds.width - (thickness * CGFloat(numberOfLines))) / CGFloat(numberOfLines + 1)
        for i in 0..<numberOfLines {
            let lineView = verticalGridLines[i]
            var frame = CGRect.zero
            frame.size.width = thickness
            frame.size.height = bounds.height
            frame.origin.x = (padding * CGFloat(i + 1)) + (thickness * CGFloat(i))
            lineView.frame = frame
        }
    }

    public func setGridHidden(_ hidden: Bool, animated: Bool) {
        internalGridHidden = hidden
        if !animated {
            horizontalGridLines.forEach { $0.alpha = hidden ? 0.0 : 1.0 }
            verticalGridLines.forEach { $0.alpha = hidden ? 0.0 : 1.0 }
            return
        }

        UIView.animate(withDuration: hidden ? 0.35 : 0.2) {
            self.horizontalGridLines.forEach { $0.alpha = hidden ? 0.0 : 1.0 }
            self.verticalGridLines.forEach { $0.alpha = hidden ? 0.0 : 1.0 }
        }
    }

    private func createNewLineView() -> UIView {
        let line = UIView(frame: .zero)
        line.backgroundColor = .white
        addSubview(line)
        return line
    }
}
