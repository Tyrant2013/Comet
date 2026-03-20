//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/20.
//

import Foundation
import Combine

final class CMAlbumViewModel: ObservableObject {
    @Published var selectedAlbum: CMAssetCollection?
    @Published var albums: [CMAssetCollection] = []
    
    var pageControl: CMPickerViewController?
    
    /// 加载相册列表
    func loadAlbums() {
        pageControl?.loading()
        
        Task {
            do {
                albums = try await CMAssetManager.shared.getAlbums()
                if let firstAlbum = albums.first {
                    selectedAlbum = firstAlbum
                }
                pageControl?.showAssets()
            } catch {
                pageControl?.showError("加载相册失败")
            }
        }
    }
}
