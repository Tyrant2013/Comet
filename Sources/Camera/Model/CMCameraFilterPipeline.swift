//
//  CMCameraFilterPipeline.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/12.
//

import Foundation
import Combine

public final class CMCameraFilterPipeline: @unchecked Sendable, ObservableObject {
    private let lock = NSLock()
    private var storage: [CMCameraFilter]
    @Published public private(set) var filters: [CMCameraFilter]
    
    public init(filters: [CMCameraFilter] = []) {
        let normalized = Self.normalize(filters)
        self.storage = normalized
        self.filters = normalized
    }
    
    public func snapshot() -> [CMCameraFilter] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
    
    public func replace(with newFilters: [CMCameraFilter]) {
        lock.lock()
        let normalized = Self.normalize(newFilters)
        storage = normalized
        lock.unlock()
        publish(normalized)
    }
    
    public func append(_ filter: CMCameraFilter) {
        lock.lock()
        var next = storage
        next.append(filter)
        let normalized = Self.normalize(next)
        storage = normalized
        lock.unlock()
        publish(normalized)
    }
    
    public func removeFirst(kind: CMCameraFilterKind) {
        lock.lock()
        var next = storage
        if let index = next.firstIndex(where: { $0.kind == kind }) {
            next.remove(at: index)
        }
        let normalized = Self.normalize(next)
        storage = normalized
        lock.unlock()
        publish(normalized)
    }
    
    public func removeAll(kind: CMCameraFilterKind) {
        lock.lock()
        let next = storage.filter { $0.kind != kind }
        let normalized = Self.normalize(next)
        storage = normalized
        lock.unlock()
        publish(normalized)
    }
    
    public func clear() {
        lock.lock()
        storage = []
        lock.unlock()
        publish([])
    }
    
    private func publish(_ newFilters: [CMCameraFilter]) {
        if Thread.isMainThread {
            filters = newFilters
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.filters = newFilters
        }
    }
    
    private static func normalize(_ filters: [CMCameraFilter]) -> [CMCameraFilter] {
        let maxCount = 16
        if filters.count <= maxCount {
            return filters
        }
        return Array(filters.prefix(maxCount))
    }
}
