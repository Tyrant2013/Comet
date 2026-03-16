//
//  CMAlbum.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import Combine
import UIKit

public enum CMAlbumType {
    case smartAlbum
    case userCreated
    case moment
    case unknown
}

public final class CMAlbum: ObservableObject, Identifiable {
    public let id: String
    public let collection: PHAssetCollection
    @Published public var assetCount: Int
    @Published public var coverImage: UIImage?
    
    private let imageManager = PHImageManager.default()
    private var fetchResult: PHFetchResult<PHAsset>?
    
    public init(collection: PHAssetCollection) {
        self.collection = collection
        self.id = collection.localIdentifier
        self.assetCount = 0
        self.fetchAssets()
    }
    
    public var title: String {
        collection.localizedTitle ?? "未命名相册"
    }
    
    public var albumType: CMAlbumType {
        switch collection.assetCollectionType {
        case .smartAlbum:
            return .smartAlbum
        case .album:
            return .userCreated
        case .moment:
            return .moment
        default:
            return .unknown
        }
    }
    
    public var startDate: Date? {
        collection.startDate
    }
    
    public var endDate: Date? {
        collection.endDate
    }
    
    public var estimatedAssetCount: Int {
        Int(collection.estimatedAssetCount)
    }
    
    public func fetchAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let result = PHAsset.fetchAssets(in: collection, options: options)
        self.fetchResult = result
        self.assetCount = result.count
        
        loadCoverImage(from: result)
    }
    
    public func getAssets() -> [CMAsset] {
        guard let fetchResult = fetchResult else { return [] }
        
        var assets: [CMAsset] = []
        fetchResult.enumerateObjects { phAsset, _, _ in
            let asset = CMAsset(asset: phAsset)
            assets.append(asset)
        }
        return assets
    }
    
    public func getAssets(limit: Int) -> [CMAsset] {
        guard let fetchResult = fetchResult else { return [] }
        
        let count = min(limit, fetchResult.count)
        var assets: [CMAsset] = []
        
        for i in 0..<count {
            let phAsset = fetchResult.object(at: i)
            let asset = CMAsset(asset: phAsset)
            assets.append(asset)
        }
        return assets
    }
    
    public func getAsset(at index: Int) -> CMAsset? {
        guard let fetchResult = fetchResult,
              index >= 0 && index < fetchResult.count else { return nil }
        
        let phAsset = fetchResult.object(at: index)
        return CMAsset(asset: phAsset)
    }
    
    private func loadCoverImage(from fetchResult: PHFetchResult<PHAsset>) {
        guard fetchResult.count > 0 else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 200, height: 200)
        
        let firstAsset = fetchResult.object(at: 0)
        imageManager.requestImage(for: firstAsset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.coverImage = image
            }
        }
    }
    
    public func reload() {
        fetchAssets()
    }
}

extension CMAlbum: Equatable {
    public static func == (lhs: CMAlbum, rhs: CMAlbum) -> Bool {
        lhs.id == rhs.id
    }
}

extension CMAlbum: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
