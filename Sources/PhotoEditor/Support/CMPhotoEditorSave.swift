import Foundation
import UIKit
import Photos
import CoreImage

public struct CMPhotoEditorSave {
    
    public enum SaveError: Error, LocalizedError {
        case noImage
        case conversionFailed
        case saveFailed(Error?)
        case permissionDenied
        
        public var errorDescription: String? {
            switch self {
            case .noImage:
                return "图片为空"
            case .conversionFailed:
                return "图片转换失败"
            case .saveFailed(let error):
                return "保存失败: \(error?.localizedDescription ?? "未知错误")"
            case .permissionDenied:
                return "没有相册访问权限"
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .permissionDenied:
                return "请在设置中开启相册访问权限"
            default:
                return nil
            }
        }
    }
    
    public static func saveToPhotoLibrary(_ image: CIImage, completion: @escaping (Result<Void, SaveError>) -> Void) {
        guard let uiImage = imageToUIImage(image) else {
            completion(.failure(.conversionFailed))
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                saveImage(uiImage, completion: completion)
            case .denied, .restricted:
                completion(.failure(.permissionDenied))
            case .notDetermined:
                completion(.failure(.permissionDenied))
            @unknown default:
                completion(.failure(.permissionDenied))
            }
        }
    }
    
    private static func saveImage(_ image: UIImage, completion: @escaping (Result<Void, SaveError>) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.saveFailed(error)))
                }
            }
        }
    }
    
    private static func imageToUIImage(_ image: CIImage) -> UIImage? {
        let context = CIContext(options: nil)
        let extent = image.extent.integral
        guard let cgImage = context.createCGImage(image, from: extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
