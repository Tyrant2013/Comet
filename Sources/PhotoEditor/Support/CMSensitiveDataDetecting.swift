import Foundation
import CoreImage

public protocol CMSensitiveDataDetecting {
    func detectSensitiveData(in image: CIImage) throws -> [CMSensitiveDataMatch]
}
