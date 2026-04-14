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
    
    public enum CMPhotoSaveFormat: String {
        case jpeg
        case png
        case heic
    }
    
    public static func save(image: UIImage, format: CMPhotoSaveFormat, quality: CGFloat = 0.8, completion: @escaping (URL?, Error?) -> Void) {
        var data: Data?
        
        switch format {
        case .jpeg:
            data = image.jpegData(compressionQuality: quality)
        case .png:
            data = image.pngData()
        case .heic:
            if #available(iOS 11.0, *) {
                let ciImage = CIImage(image: image)
                let context = CIContext()
                data = context.heifRepresentation(of: ciImage!, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
            } else {
                data = image.jpegData(compressionQuality: quality)
            }
        }
        
        guard let imageData = data else {
            completion(nil, NSError(domain: "CMPhotoEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"]))
            return
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "edited_\(UUID().uuidString).\(format.rawValue)"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            completion(fileURL, nil)
        } catch {
            completion(nil, error)
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
    
    public static func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            completion(success, error)
        }
    }
    
    private static func saveImage(_ image: UIImage, completion: @escaping (Result<Void, SaveError>) -> Void) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            let _ = request.placeholderForCreatedAsset
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
