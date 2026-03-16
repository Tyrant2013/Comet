//
//  CMImageCache.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import UIKit
import Combine
import Photos

public enum CMImageCacheError: Error {
    case assetNotFound
    case loadFailed(String)
    case cacheUnavailable
}

extension CMImageCacheError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "资源未找到"
        case .loadFailed(let message):
            return "加载失败：\(message)"
        case .cacheUnavailable:
            return "缓存不可用"
        }
    }
}

public enum CMImageLoadState {
    case idle
    case loading(progress: Float)
    case loaded(UIImage)
    case failed(Error)
}

public final class CMImageCache: ObservableObject {
    
    public static let shared = CMImageCache()
    
    @Published public var memoryUsage: Int = 0
    @Published public var diskUsage: Int = 0
    
    private let memoryCache: NSCache<NSString, CMCacheEntry>
    private let diskCacheURL: URL
    private let fileManager = FileManager.default
    private let imageManager = PHImageManager.default()
    private let queue = DispatchQueue(label: "com.comet.imagecache", qos: .userInitiated)
    
    private var activeRequests: [String: PHImageRequestID] = [:]
    private var preloadTasks: [String: AnyCancellable] = [:]
    
    private let maxMemoryCacheSize: Int
    private let maxDiskCacheSize: Int
    
    private let memoryCacheLimit: Int = 100 * 1024 * 1024
    private let diskCacheLimit: Int = 500 * 1024 * 1024
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.memoryCache = NSCache<NSString, CMCacheEntry>()
        self.maxMemoryCacheSize = memoryCacheLimit
        self.maxDiskCacheSize = diskCacheLimit
        
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = cachesURL.appendingPathComponent("CMImageCache")
        
        setupMemoryCache()
        setupDiskCache()
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryCache() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = maxMemoryCacheSize
    }
    
    private func setupDiskCache() {
        if !fileManager.fileExists(atPath: diskCacheURL.path) {
            try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        }
        updateDiskUsage()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.clearMemoryCache()
            }
            .store(in: &cancellables)
    }
    
    public func image(for key: String) -> UIImage? {
        if let entry = memoryCache.object(forKey: key as NSString) {
            entry.access()
            return entry.image
        }
        
        if let image = loadImageFromDisk(for: key) {
            let entry = CMCacheEntry(image: image)
            memoryCache.setObject(entry, forKey: key as NSString, cost: image.cost)
            return image
        }
        
        return nil
    }
    
    public func loadImage(for asset: PHAsset, size: CGSize, mode: PHImageContentMode = .aspectFill) -> AnyPublisher<CMImageLoadState, Never> {
        let key = cacheKey(for: asset.localIdentifier, size: size)
        
        if let cachedImage = image(for: key) {
            return Just(.loaded(cachedImage)).eraseToAnyPublisher()
        }
        
        return Future<CMImageLoadState, Never> { [weak self] promise in
            guard let self = self else {
                promise(.success(.idle))
                return
            }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.progressHandler = { progress, _, _, _ in
                promise(.success(.loading(progress: Float(progress))))
            }
            
            let targetSize = CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale)
            
            let requestID = self.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: mode, options: options) { image, info in
                self.queue.async {
                    if let error = info?[PHImageErrorKey] as? Error {
                        promise(.success(.failed(error)))
                        self.activeRequests.removeValue(forKey: key)
                        return
                    }
                    
                    if let image = image {
                        self.cacheImage(image, for: key)
                        promise(.success(.loaded(image)))
                    } else {
                        promise(.success(.idle))
                    }
                    
                    self.activeRequests.removeValue(forKey: key)
                }
            }
            
            self.activeRequests[key] = requestID
        }
        .eraseToAnyPublisher()
    }
    
    public func preloadImages(for assets: [PHAsset], size: CGSize, mode: PHImageContentMode = .aspectFill) {
        for asset in assets {
            let key = cacheKey(for: asset.localIdentifier, size: size)
            
            if image(for: key) != nil {
                continue
            }
            
            if preloadTasks[key] != nil {
                continue
            }
            
            let cancellable = loadImage(for: asset, size: size, mode: mode)
                .sink { _ in }
            
            preloadTasks[key] = cancellable
        }
    }
    
    public func cancelPreload(for asset: PHAsset, size: CGSize) {
        let key = cacheKey(for: asset.localIdentifier, size: size)
        
        if let cancellable = preloadTasks[key] {
            cancellable.cancel()
            preloadTasks.removeValue(forKey: key)
        }
        
        if let requestID = activeRequests[key] {
            imageManager.cancelImageRequest(requestID)
            activeRequests.removeValue(forKey: key)
        }
    }
    
    public func cancelAllPreloads() {
        preloadTasks.values.forEach { $0.cancel() }
        preloadTasks.removeAll()
        
        activeRequests.values.forEach { imageManager.cancelImageRequest($0) }
        activeRequests.removeAll()
    }
    
    public func cacheImage(_ image: UIImage, for key: String) {
        let entry = CMCacheEntry(image: image)
        memoryCache.setObject(entry, forKey: key as NSString, cost: image.cost)
        
        queue.async { [weak self] in
            self?.saveImageToDisk(image, for: key)
        }
    }
    
    public func removeImage(for key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        
        queue.async { [weak self] in
            self?.removeImageFromDisk(for: key)
        }
    }
    
    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
        updateMemoryUsage()
    }
    
    public func clearDiskCache() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            try? self.fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
            self.updateDiskUsage()
        }
    }
    
    public func clearAllCache() {
        clearMemoryCache()
        clearDiskCache()
    }
    
    public func trimMemoryCache(toSize size: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let currentUsage = self.calculateMemoryUsage()
            
            if currentUsage <= size {
                return
            }
            
            let entriesToRemove = currentUsage - size
            var removedSize = 0
            
            let sortedKeys = self.getLRUKeys()
            
            for key in sortedKeys {
                if removedSize >= entriesToRemove {
                    break
                }
                
                if let entry = self.memoryCache.object(forKey: key as NSString) {
                    removedSize += entry.image.cost
                    self.memoryCache.removeObject(forKey: key as NSString)
                }
            }
            
            self.updateMemoryUsage()
        }
    }
    
    public func trimDiskCache(toSize size: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let currentUsage = self.diskUsage
            
            if currentUsage <= size {
                return
            }
            
            let entriesToRemove = currentUsage - size
            var removedSize = 0
            
            let sortedKeys = self.getLRUDiskKeys()
            
            for key in sortedKeys {
                if removedSize >= entriesToRemove {
                    break
                }
                
                let fileURL = self.diskCacheURL.appendingPathComponent(key)
                if let fileSize = try? self.fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int {
                    removedSize += fileSize
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }
            
            self.updateDiskUsage()
        }
    }
    
    private func cacheKey(for identifier: String, size: CGSize) -> String {
        return "\(identifier)_\(Int(size.width))x\(Int(size.height))"
    }
    
    private func loadImageFromDisk(for key: String) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    private func saveImageToDisk(_ image: UIImage, for key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }
        
        let fileURL = diskCacheURL.appendingPathComponent(key)
        
        try? data.write(to: fileURL)
        updateDiskUsage()
        
        if diskUsage > maxDiskCacheSize {
            trimDiskCache(toSize: Int(Double(maxDiskCacheSize) * 0.8))
        }
    }
    
    private func removeImageFromDisk(for key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
        updateDiskUsage()
    }
    
    private func updateMemoryUsage() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let usage = self.calculateMemoryUsage()
            DispatchQueue.main.async {
                self.memoryUsage = usage
            }
        }
    }
    
    private func updateDiskUsage() {
        let usage = calculateDiskUsage()
        DispatchQueue.main.async { [weak self] in
            self?.diskUsage = usage
        }
    }
    
    private func calculateMemoryUsage() -> Int {
        return memoryCacheLimit
    }
    
    private func calculateDiskUsage() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        
        var totalSize = 0
        
        for url in contents {
            if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func getLRUKeys() -> [String] {
        var entries: [(key: String, lastAccess: Date)] = []
        
        memoryCache.object(forKey: "" as NSString)
        
        return entries.sorted { $0.lastAccess < $1.lastAccess }.map { $0.key }
    }
    
    private func getLRUDiskKeys() -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else {
            return []
        }
        
        var entries: [(key: String, modificationDate: Date)] = []
        
        for url in contents {
            if let modificationDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                entries.append((key: url.lastPathComponent, modificationDate: modificationDate))
            }
        }
        
        return entries.sorted { $0.modificationDate < $1.modificationDate }.map { $0.key }
    }
}

private final class CMCacheEntry {
    let image: UIImage
    private(set) var lastAccess: Date
    
    init(image: UIImage) {
        self.image = image
        self.lastAccess = Date()
    }
    
    func access() {
        lastAccess = Date()
    }
}

extension UIImage {
    var cost: Int {
        let bytesPerPixel = 4
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        return width * height * bytesPerPixel
    }
}

extension CMImageCache {
    public func loadVisibleImages(assets: [PHAsset], size: CGSize, visibleRange: Range<Int>, mode: PHImageContentMode = .aspectFill) {
        let visibleAssets = Array(assets[visibleRange])
        
        for asset in visibleAssets {
            _ = loadImage(for: asset, size: size, mode: mode)
                .sink { _ in }
        }
    }
    
    public func preloadNearbyImages(assets: [PHAsset], size: CGSize, currentIndex: Int, preloadCount: Int = 3, mode: PHImageContentMode = .aspectFill) {
        let startIndex = max(0, currentIndex - preloadCount)
        let endIndex = min(assets.count - 1, currentIndex + preloadCount)
        
        var assetsToPreload: [PHAsset] = []
        
        for i in startIndex...endIndex {
            if i != currentIndex {
                assetsToPreload.append(assets[i])
            }
        }
        
        preloadImages(for: assetsToPreload, size: size, mode: mode)
    }
    
    public func cancelInvisibleAssets(assets: [PHAsset], size: CGSize, visibleRange: Range<Int>) {
        for (index, asset) in assets.enumerated() {
            if !visibleRange.contains(index) {
                cancelPreload(for: asset, size: size)
            }
        }
    }
}
