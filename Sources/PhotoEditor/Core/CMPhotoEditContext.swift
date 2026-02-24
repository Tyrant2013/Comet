import Foundation
import CoreImage

public struct CMPhotoEditContext {
    public let originalImage: CIImage
    public var image: CIImage
    public var metadata: [String: Any]

    public init(image: CIImage, metadata: [String: Any] = [:]) {
        self.originalImage = image
        self.image = image
        self.metadata = metadata
    }

    public mutating func resetImage() {
        image = originalImage
    }
}
