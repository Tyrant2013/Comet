import Foundation
import CoreImage

public protocol CMPhotoEditOperation {
    var id: String { get }
    func apply(to context: inout CMPhotoEditContext) throws
}
