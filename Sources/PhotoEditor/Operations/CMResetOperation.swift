import Foundation

public struct CMResetOperation: CMPhotoEditOperation {
    public let id = "reset"

    public init() {}

    public func apply(to context: inout CMPhotoEditContext) throws {
        context.resetImage()
    }
    
    public static func == (lhs: CMResetOperation, rhs: CMResetOperation) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
