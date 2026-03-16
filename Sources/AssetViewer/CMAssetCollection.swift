//
//  CMAssetCollection.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import Combine

public enum CMAssetCollectionType {
    case allPhotos
    case album
    case smartAlbum
    case custom
}

public final class CMAssetCollection: ObservableObject, Identifiable {
    public let id: String
    @Published public var assets: [CMAsset] = []
    @Published public var isLoading: Bool = false
    @Published public var hasMore: Bool = true
    
    private let imageManager = PHImageManager.default()
    private var fetchResult: PHFetchResult<PHAsset>?
    private var collectionType: CMAssetCollectionType
    private var assetCollection: PHAssetCollection?
    private var currentLimit: Int = 50
    
    public init(collectionType: CMAssetCollectionType = .allPhotos, assetCollection: PHAssetCollection? = nil) {
        self.id = UUID().uuidString
        self.collectionType = collectionType
        self.assetCollection = assetCollection
    }
    
    public var count: Int {
        assets.count
    }
    
    public var totalCount: Int {
        fetchResult?.count ?? 0
    }
    
    public func fetchAssets(limit: Int = 50, offset: Int = 0) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = limit
            
            let fetchResult: PHFetchResult<PHAsset>
            
            switch self.collectionType {
            case .allPhotos:
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
                
            case .album, .smartAlbum:
                guard let assetCollection = self.assetCollection else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                fetchResult = PHAsset.fetchAssets(in: assetCollection, options: options)
                
            case .custom:
                fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            }
            
            self.fetchResult = fetchResult
            
            var newAssets: [CMAsset] = []
            let startIndex = offset
            let endIndex = min(offset + limit, fetchResult.count)
            
            for i in startIndex..<endIndex {
                let phAsset = fetchResult.object(at: i)
                let asset = CMAsset(asset: phAsset)
                newAssets.append(asset)
            }
            
            DispatchQueue.main.async {
                if offset == 0 {
                    self.assets = newAssets
                } else {
                    self.assets.append(contentsOf: newAssets)
                }
                self.hasMore = endIndex < fetchResult.count
                self.isLoading = false
            }
        }
    }
    
    public func loadMoreAssets() {
        guard !isLoading && hasMore else { return }
        fetchAssets(limit: currentLimit, offset: assets.count)
    }
    
    public func reload() {
        assets.removeAll()
        fetchAssets(limit: currentLimit, offset: 0)
    }
    
    public func setLimit(_ limit: Int) {
        currentLimit = limit
    }
    
    public func getAsset(at index: Int) -> CMAsset? {
        guard index >= 0 && index < assets.count else { return nil }
        return assets[index]
    }
    
    public func appendAssets(_ newAssets: [CMAsset]) {
        assets.append(contentsOf: newAssets)
    }
    
    public func removeAsset(at index: Int) {
        guard index >= 0 && index < assets.count else { return }
        assets.remove(at: index)
    }
    
    public func removeAsset(_ asset: CMAsset) {
        assets.removeAll { $0.id == asset.id }
    }
    
    public func clearAssets() {
        assets.removeAll()
    }
    
    public func filterAssets(predicate: (CMAsset) -> Bool) -> [CMAsset] {
        assets.filter(predicate)
    }
    
    public func sortAssets(by comparator: (CMAsset, CMAsset) -> Bool) {
        assets.sort(by: comparator)
    }
    
    public func fetchAssetsWithMediaType(_ mediaType: PHAssetMediaType, limit: Int = 50) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = limit
            
            let fetchResult = PHAsset.fetchAssets(with: mediaType, options: options)
            self.fetchResult = fetchResult
            
            var newAssets: [CMAsset] = []
            for i in 0..<min(limit, fetchResult.count) {
                let phAsset = fetchResult.object(at: i)
                let asset = CMAsset(asset: phAsset)
                newAssets.append(asset)
            }
            
            DispatchQueue.main.async {
                self.assets = newAssets
                self.hasMore = limit < fetchResult.count
                self.isLoading = false
            }
        }
    }
    
    public func fetchFavoriteAssets(limit: Int = 50) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = limit
            options.predicate = NSPredicate(format: "favorite == YES")
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
            self.fetchResult = fetchResult
            
            var newAssets: [CMAsset] = []
            for i in 0..<min(limit, fetchResult.count) {
                let phAsset = fetchResult.object(at: i)
                let asset = CMAsset(asset: phAsset)
                newAssets.append(asset)
            }
            
            DispatchQueue.main.async {
                self.assets = newAssets
                self.hasMore = limit < fetchResult.count
                self.isLoading = false
            }
        }
    }
}

extension CMAssetCollection: Equatable {
    public static func == (lhs: CMAssetCollection, rhs: CMAssetCollection) -> Bool {
        lhs.id == rhs.id
    }
}

extension CMAssetCollection: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
