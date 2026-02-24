import Foundation
import CoreImage
import AVFoundation

public struct CMFilterOperation: CMPhotoEditOperation {
    public let id = "filter"
    public let filter: CMPhotoEditorFilter
    private let metalProcessor: CMPhotoEditorMetalFilterProcessor?

    public init(filter: CMPhotoEditorFilter) {
        self.filter = filter
        self.metalProcessor = CMPhotoEditorMetalFilterProcessor.shared
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        let filterType = filter.metalFilterType
        guard filterType > 0 else { return }

        if let outputPixelBuffer = metalProcessor?.applyFilter(to: context.image, filterType: filterType) {
            let outputImage = CIImage(cvPixelBuffer: outputPixelBuffer)
            context.image = outputImage.cropped(to: context.image.extent)
        }
    }
}
