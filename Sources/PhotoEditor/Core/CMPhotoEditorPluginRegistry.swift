import Foundation

public final class CMPhotoEditorPluginRegistry {
    public typealias Factory = (_ configuration: Any) -> CMPhotoEditOperation?

    private var factories: [String: Factory] = [:]

    public init() {}

    public func register(_ id: String, factory: @escaping Factory) {
        factories[id] = factory
    }

    public func makeOperation(id: String, configuration: Any) -> CMPhotoEditOperation? {
        factories[id]?(configuration)
    }
}
