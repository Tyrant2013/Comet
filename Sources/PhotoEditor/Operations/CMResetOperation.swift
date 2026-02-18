import Foundation

public struct CMResetOperation: CMPhotoEditOperation {
    public let id = "reset"

    public init() {}

    public func apply(to context: inout CMPhotoEditContext) throws {
        context.resetImage()
    }
}
