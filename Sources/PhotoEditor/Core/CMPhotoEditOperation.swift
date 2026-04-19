import Foundation
import CoreImage

public protocol CMPhotoEditOperation: Hashable {
    var id: String { get }
    var hashValue: Int { get }
    func apply(to context: inout CMPhotoEditContext) throws
}

extension CMPhotoEditOperation {
    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}
