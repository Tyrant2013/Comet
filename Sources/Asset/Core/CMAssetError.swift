import Foundation

/// 相册操作错误定义
enum CMAssetError: Error {
    /// 权限错误
    case permissionDenied
    /// 操作失败
    case operationFailed(String)
    /// 相册不存在
    case albumNotFound
    /// 图片不存在
    case assetNotFound
    /// 无效的参数
    case invalidParameter
    /// 未知错误
    case unknown
    
    /// 错误描述
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "相册访问权限被拒绝"
        case .operationFailed(let message):
            return "操作失败: \(message)"
        case .albumNotFound:
            return "相册不存在"
        case .assetNotFound:
            return "图片不存在"
        case .invalidParameter:
            return "无效的参数"
        case .unknown:
            return "未知错误"
        }
    }
}