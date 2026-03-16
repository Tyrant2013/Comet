//
//  CMAlbumManager.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import Combine

public final class CMAlbumManager: NSObject, ObservableObject {
    public static let shared = CMAlbumManager()
    
    @Published public var albums: [CMAlbum] = []
    @Published public var isLoading: Bool = false
    @Published public var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private let photoLibrary = PHPhotoLibrary.shared()
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupPhotoLibraryObserver()
        checkAuthorizationStatus()
    }
    
    public func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public func requestAuthorization(completion: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                completion(status)
            }
        }
    }
    
    public func fetchAllAlbums() {
        guard authorizationStatus == .authorized else {
            requestAuthorization { [weak self] status in
                if status == .authorized {
                    self?.fetchAllAlbums()
                }
            }
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allAlbums: [CMAlbum] = []
            
            let smartAlbums = self.fetchSmartAlbums()
            let userAlbums = self.fetchUserAlbums()
            
            allAlbums.append(contentsOf: smartAlbums)
            allAlbums.append(contentsOf: userAlbums)
            
            DispatchQueue.main.async {
                self.albums = allAlbums
                self.isLoading = false
            }
        }
    }
    
    private func fetchSmartAlbums() -> [CMAlbum] {
        var albums: [CMAlbum] = []
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: options)
        
        smartAlbums.enumerateObjects { collection, _, _ in
            let album = CMAlbum(collection: collection)
            albums.append(album)
        }
        
        return albums
    }
    
    private func fetchUserAlbums() -> [CMAlbum] {
        var albums: [CMAlbum] = []
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        
        userAlbums.enumerateObjects { collection, _, _ in
            let album = CMAlbum(collection: collection)
            albums.append(album)
        }
        
        return albums
    }
    
    public func fetchAlbumAssets(album: CMAlbum, limit: Int = 50) -> [CMAsset] {
        return album.getAssets(limit: limit)
    }
    
    public func createAlbum(name: String, completion: @escaping (Result<CMAlbum, Error>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CMAlbumError.unauthorized))
            return
        }
        
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = createRequest.placeholderForCreatedAssetCollection
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                guard success, let placeholder = placeholder else {
                    completion(.failure(error ?? CMAlbumError.creationFailed))
                    return
                }
                
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let collection = fetchResult.firstObject else {
                    completion(.failure(CMAlbumError.collectionNotFound))
                    return
                }
                
                let album = CMAlbum(collection: collection)
                self?.albums.append(album)
                completion(.success(album))
            }
        }
    }
    
    public func deleteAlbum(album: CMAlbum, completion: @escaping (Result<Void, Error>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CMAlbumError.unauthorized))
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.deleteAssetCollections([album.collection] as NSArray)
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                guard success else {
                    completion(.failure(error ?? CMAlbumError.deletionFailed))
                    return
                }
                
                self?.albums.removeAll { $0.id == album.id }
                completion(.success(()))
            }
        }
    }
    
    public func addAssets(assets: [PHAsset], to album: CMAlbum, completion: @escaping (Result<Void, Error>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CMAlbumError.unauthorized))
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            guard let addRequest = PHAssetCollectionChangeRequest(for: album.collection) else {
                return
            }
            addRequest.addAssets(assets as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    album.reload()
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? CMAlbumError.addAssetsFailed))
                }
            }
        }
    }
    
    public func removeAssets(assets: [PHAsset], from album: CMAlbum, completion: @escaping (Result<Void, Error>) -> Void) {
        guard authorizationStatus == .authorized else {
            completion(.failure(CMAlbumError.unauthorized))
            return
        }
        
        PHPhotoLibrary.shared().performChanges {
            guard let removeRequest = PHAssetCollectionChangeRequest(for: album.collection) else {
                return
            }
            removeRequest.removeAssets(assets as NSArray)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    album.reload()
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? CMAlbumError.removeAssetsFailed))
                }
            }
        }
    }
    
    private func setupPhotoLibraryObserver() {
        PHPhotoLibrary.shared().register(self)
    }
    
    public func reloadAlbums() {
        fetchAllAlbums()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension CMAlbumManager: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var updatedAlbums = self.albums
            
            for (index, album) in self.albums.enumerated() {
                if let changeDetails = changeInstance.changeDetails(for: album.collection) {
                    if changeDetails.objectWasDeleted {
                        updatedAlbums.remove(at: index)
                    } else if let newCollection = changeDetails.objectAfterChanges {
                        let newAlbum = CMAlbum(collection: newCollection)
                        updatedAlbums[index] = newAlbum
                    }
                }
            }
            
            self.albums = updatedAlbums
        }
    }
}

public enum CMAlbumError: LocalizedError {
    case unauthorized
    case creationFailed
    case deletionFailed
    case collectionNotFound
    case addAssetsFailed
    case removeAssetsFailed
    
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "未授权访问相册"
        case .creationFailed:
            return "创建相册失败"
        case .deletionFailed:
            return "删除相册失败"
        case .collectionNotFound:
            return "找不到相册"
        case .addAssetsFailed:
            return "添加图片失败"
        case .removeAssetsFailed:
            return "移除图片失败"
        }
    }
}
