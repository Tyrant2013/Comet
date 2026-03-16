//
//  CMAssetViewer.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import Combine
import UIKit

public enum CMAssetViewerError: Error {
    case permissionDenied
    case libraryUnavailable
    case fetchFailed(String)
}

extension CMAssetViewerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "相册访问权限被拒绝，请在系统设置中开启。"
        case .libraryUnavailable:
            return "无法访问相册。"
        case .fetchFailed(let message):
            return "获取资源失败：\(message)"
        }
    }
}

public final class CMAssetViewer: ObservableObject {
    @Published public var albums: [CMAlbum] = []
    @Published public var currentAlbum: CMAlbum?
    @Published public var currentCollection: CMAssetCollection?
    @Published public var selectedAssets: Set<String> = []
    @Published public var isAuthorized: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var error: CMAssetViewerError?
    
    private let imageManager = PHImageManager.default()
    private var cancellables = Set<AnyCancellable>()
    private var photoLibraryObserver: NSObjectProtocol?
    
    public init() {
        setupPhotoLibraryObserver()
        checkAuthorizationStatus()
    }
    
    deinit {
        if let observer = photoLibraryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.isAuthorized = true
                    self?.loadAlbums()
                case .denied, .restricted:
                    self?.isAuthorized = false
                    self?.error = .permissionDenied
                case .notDetermined:
                    self?.isAuthorized = false
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            isAuthorized = true
            loadAlbums()
        case .denied, .restricted:
            isAuthorized = false
            error = .permissionDenied
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    public func loadAlbums() {
        guard isAuthorized else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var fetchedAlbums: [CMAlbum] = []
            
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
            smartAlbums.enumerateObjects { collection, _, _ in
                let album = CMAlbum(collection: collection)
                fetchedAlbums.append(album)
            }
            
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            userAlbums.enumerateObjects { collection, _, _ in
                let album = CMAlbum(collection: collection)
                fetchedAlbums.append(album)
            }
            
            DispatchQueue.main.async {
                self.albums = fetchedAlbums
                self.isLoading = false
            }
        }
    }
    
    public func selectAlbum(_ album: CMAlbum) {
        currentAlbum = album
        let collection = CMAssetCollection(collectionType: .album, assetCollection: album.collection)
        currentCollection = collection
        collection.fetchAssets()
    }
    
    public func loadAllPhotos() {
        guard isAuthorized else { return }
        
        let collection = CMAssetCollection(collectionType: .allPhotos)
        currentCollection = collection
        collection.fetchAssets()
    }
    
    public func loadFavoritePhotos() {
        guard isAuthorized else { return }
        
        let collection = CMAssetCollection(collectionType: .custom)
        currentCollection = collection
        collection.fetchFavoriteAssets()
    }
    
    public func toggleAssetSelection(_ asset: CMAsset) {
        if selectedAssets.contains(asset.id) {
            selectedAssets.remove(asset.id)
        } else {
            selectedAssets.insert(asset.id)
        }
    }
    
    public func selectAllAssets() {
        guard let collection = currentCollection else { return }
        selectedAssets = Set(collection.assets.map { $0.id })
    }
    
    public func deselectAllAssets() {
        selectedAssets.removeAll()
    }
    
    public var selectedAssetObjects: [CMAsset] {
        guard let collection = currentCollection else { return [] }
        return collection.assets.filter { selectedAssets.contains($0.id) }
    }
    
    public var selectedCount: Int {
        selectedAssets.count
    }
    
    public func deleteSelectedAssets(completion: @escaping (Bool) -> Void) {
        guard !selectedAssets.isEmpty else {
            completion(false)
            return
        }
        
        guard let collection = currentCollection else {
            completion(false)
            return
        }
        
        let assetsToDelete = collection.assets.filter { selectedAssets.contains($0.id) }
        let phAssets = assetsToDelete.map { $0.asset }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(phAssets as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.deselectAllAssets()
                    self?.currentCollection?.reload()
                    self?.currentAlbum?.reload()
                }
                completion(success)
            }
        }
    }
    
    public func saveImage(_ image: UIImage, toAlbum album: CMAlbum? = nil, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges { [weak self] in
            let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            
            if let album = album {
                guard let collectionFetchResult = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [album.id],
                    options: nil
                ).firstObject else { return }
                
                let addAssetRequest = PHAssetCollectionChangeRequest(for: collectionFetchResult)
                addAssetRequest?.addAssets(NSArray(object: creationRequest.placeholderForCreatedAsset as Any))
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.currentCollection?.reload()
                    self?.currentAlbum?.reload()
                }
                completion(success)
            }
        }
    }
    
    public func saveVideo(at url: URL, toAlbum album: CMAlbum? = nil, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges { [weak self] in
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            
            if let album = album, let placeholder = creationRequest?.placeholderForCreatedAsset {
                guard let collectionFetchResult = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [album.id],
                    options: nil
                ).firstObject else { return }
                
                let addAssetRequest = PHAssetCollectionChangeRequest(for: collectionFetchResult)
                addAssetRequest?.addAssets(NSArray(object: placeholder))
            }
        } completionHandler: { success, error in
            DispatchQueue.main.async { [weak self] in
                if success {
                    self?.currentCollection?.reload()
                    self?.currentAlbum?.reload()
                }
                completion(success)
            }
        }
    }
    
    public func refresh() {
        loadAlbums()
        currentCollection?.reload()
        currentAlbum?.reload()
    }
    
    private func setupPhotoLibraryObserver() {
        photoLibraryObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PHPhotoLibraryDidChange"),
            object: PHPhotoLibrary.shared(),
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }
    
    public func getSmartAlbums() -> [CMAlbum] {
        albums.filter { $0.albumType == .smartAlbum }
    }
    
    public func getUserAlbums() -> [CMAlbum] {
        albums.filter { $0.albumType == .userCreated }
    }
    
    public func searchAssets(with query: String) -> [CMAsset] {
        guard let collection = currentCollection else { return [] }
        
        return collection.assets.filter { asset in
            if let creationDate = asset.creationDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateString = formatter.string(from: creationDate)
                return dateString.contains(query)
            }
            return false
        }
    }
}
