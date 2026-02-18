import Foundation
import CoreImage

public struct CMFilterOperation: CMPhotoEditOperation {
    public let id = "filter"
    public let filter: CMPhotoEditorFilter

    public init(filter: CMPhotoEditorFilter) {
        self.filter = filter
    }

    public func apply(to context: inout CMPhotoEditContext) throws {
        guard let filterName = filter.coreImageName else { return }
        guard let ciFilter = CIFilter(name: filterName) else { return }
        ciFilter.setValue(context.image, forKey: kCIInputImageKey)
        if let output = ciFilter.outputImage {
            context.image = output.cropped(to: context.image.extent)
        }
    }
}
