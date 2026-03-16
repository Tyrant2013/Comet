//
//  CMAsset.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import UIKit
import Combine

public enum CMAssetType {
    case image
    case video
    case livePhoto
    case unknown
}

public enum CMAssetLocationType {
    case local
    case iCloud
    case unknown
}

public final class CMAsset: ObservableObject, Identifiable {
    public let id: String
    public let asset: PHAsset
    @Published public var locationType: CMAssetLocationType
    @Published public var isDownloading: Bool = false
    
    private let imageManager = PHImageManager.default()
    private var downloadProgress: PHImageRequestID?
    
    public init(asset: PHAsset) {
        self.asset = asset
        self.id = asset.localIdentifier
        self.locationType = .unknown
        self.updateLocationType()
    }
    
    public var assetType: CMAssetType {
        switch asset.mediaType {
        case .image:
            if asset.mediaSubtypes.contains(.photoLive) {
                return .livePhoto
            }
            return .image
        case .video:
            return .video
        default:
            return .unknown
        }
    }
    
    public var creationDate: Date? {
        asset.creationDate
    }
    
    public var modificationDate: Date? {
        asset.modificationDate
    }
    
    public var duration: TimeInterval {
        asset.duration
    }
    
    public var isFavorite: Bool {
        asset.isFavorite
    }
    
    public var isHidden: Bool {
        #if compiler(>=6.0)
        if #available(iOS 16.0, *) {
            return asset.isHidden
        } else {
            return false
        }
        #else
        return false
        #endif
    }
    
    public var location: CLLocation? {
        asset.location
    }
    
    public func requestThumbnail(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    public func requestImage(completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = PHImageManagerMaximumSize
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    public func requestImageData(completion: @escaping (Data?, String?, UIImage.Orientation, [AnyHashable: Any]?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.progressHandler = { progress, _, _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = true
            }
        }
        
        imageManager.requestImageData(for: asset, options: options) { data, dataUTI, orientation, info in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                completion(data, dataUTI, orientation, info)
            }
        }
    }
    
    public func requestAVAsset(completion: @escaping (AVAsset?, AVAudioMix?, [AnyHashable: Any]?) -> Void) {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.progressHandler = { progress, _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = true
            }
        }
        
        imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, audioMix, info in
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
                completion(avAsset, audioMix, info)
            }
        }
    }
    
    private func updateLocationType() {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        
        let targetSize = CGSize(width: 1, height: 1)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, info in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool {
                    self.locationType = isInCloud ? .iCloud : .local
                } else {
                    self.locationType = .local
                }
            }
        }
    }
    
    public func cancelAllRequests() {
        if let downloadProgress = downloadProgress {
            imageManager.cancelImageRequest(downloadProgress)
        }
    }
    
    deinit {
        cancelAllRequests()
    }
}

extension CMAsset: Equatable {
    public static func == (lhs: CMAsset, rhs: CMAsset) -> Bool {
        lhs.id == rhs.id
    }
}

extension CMAsset: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
