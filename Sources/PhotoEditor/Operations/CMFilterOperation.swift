import Foundation
import CoreImage
import AVFoundation
import UIKit

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
    
    public func previewFilter(on image: UIImage, intensity: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        guard let filterName = filter.coreImageName else { return image }
        let filter = CIFilter(name: filterName)
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        if filterName == "CISepiaTone" || filterName == "CIColorMonochrome" {
            filter?.setValue(intensity, forKey: kCIInputIntensityKey)
        }
        
        guard let outputImage = filter?.outputImage else { return nil }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    public static func == (lhs: CMFilterOperation, rhs: CMFilterOperation) -> Bool {
        return lhs.id == rhs.id && lhs.filter == rhs.filter
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(filter)
    }
}

extension CMPhotoEditorFilter {
    public func preview(on image: UIImage) -> UIImage? {
        let operation = CMFilterOperation(filter: self)
        return operation.previewFilter(on: image, intensity: intensity)
    }
}
