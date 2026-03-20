//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/19.
//

import Foundation
import Photos

final class CMFetchResult<T: PHObject>: Identifiable {
    var id = UUID()
    private let result: PHFetchResult<T>?
    
    init(result: PHFetchResult<T>?) {
        self.result = result
    }
    
    var count: Int { result?.count ?? 0 }
    var isEmpty: Bool { result?.count == 0 }
    
    subscript(index: Int) -> T? {
        guard index >= 0 && index < count else { return nil }
        
        return result?.object(at: index)
    }
    
    func object(at index: Int) -> T? {
        self[index]
    }
    
//    func makeIterator() -> CMFetchResultIterator<T> {
//        CMFetchResultIterator(result: result)
//    }
    
    func asyncStream() -> AsyncStream<T> {
        AsyncStream { continuation in
            result?.enumerateObjects { object, _, stop in
                continuation.yield(object)
            }
            continuation.finish()
        }
    }
}

//struct CMFetchResultIterator<T: PHObject>: IteratorProtocol {
//    private let result: PHFetchResult<T>
//    private var index: Int = 0
//    
//    init(result: PHFetchResult<T>) {
//        self.result = result
//    }
//    
//    mutating func next() -> T? {
//        guard index < result.count else { return nil }
//        let object = result.object(at: index)
//        index += 1
//        return object
//    }
//}
