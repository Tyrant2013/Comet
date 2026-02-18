import Foundation
import CoreGraphics

public struct CMSensitiveDataMatch: Equatable, Sendable {
    public let bounds: CGRect
    public let text: String

    public init(bounds: CGRect, text: String) {
        self.bounds = bounds
        self.text = text
    }
}
