import Foundation
import CoreGraphics

public struct CMCropState: Sendable {
    public let imageSize: CGSize
    public private(set) var zoomScale: CGFloat
    public private(set) var panOffset: CGPoint
    public private(set) var rotationDegrees: CGFloat
    public var outputAspectRatio: CGFloat

    private let defaultZoomScale: CGFloat = 1
    private let defaultPanOffset: CGPoint = .zero
    private let defaultRotationDegrees: CGFloat = 0

    public init(imageSize: CGSize,
                zoomScale: CGFloat = 1,
                panOffset: CGPoint = .zero,
                rotationDegrees: CGFloat = 0,
                outputAspectRatio: CGFloat = 1) {
        self.imageSize = imageSize
        self.zoomScale = max(zoomScale, 1)
        self.panOffset = panOffset
        self.rotationDegrees = rotationDegrees
        self.outputAspectRatio = max(outputAspectRatio, 0.1)
    }

    public mutating func updateZoomScale(_ scale: CGFloat) {
        zoomScale = max(scale, 1)
    }

    public mutating func updatePanOffset(_ offset: CGPoint) {
        panOffset = offset
    }

    public mutating func rotate(by degrees: CGFloat) {
        rotationDegrees += degrees
    }

    public mutating func reset() {
        zoomScale = defaultZoomScale
        panOffset = defaultPanOffset
        rotationDegrees = defaultRotationDegrees
    }

    public func cropRect(in extent: CGRect) -> CGRect {
        let safeExtent = extent.isNull ? CGRect(origin: .zero, size: imageSize) : extent
        let baseWidth = safeExtent.width / zoomScale
        let baseHeight = baseWidth / outputAspectRatio
        let limitedHeight = min(baseHeight, safeExtent.height / zoomScale)
        let finalWidth = limitedHeight * outputAspectRatio

        let centerX = safeExtent.midX + panOffset.x * safeExtent.width
        let centerY = safeExtent.midY + panOffset.y * safeExtent.height

        let x = max(safeExtent.minX, min(centerX - finalWidth / 2, safeExtent.maxX - finalWidth))
        let y = max(safeExtent.minY, min(centerY - limitedHeight / 2, safeExtent.maxY - limitedHeight))

        return CGRect(x: x, y: y, width: finalWidth, height: limitedHeight).integral
    }
}
