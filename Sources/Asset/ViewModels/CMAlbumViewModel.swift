//
//  CMAlbumViewModel.swift
//  Comet
//

import Foundation
import Combine

final class CMAlbumViewModel: ObservableObject {
    @Published var selectedAlbum: CMAssetCollection?
    @Published var albums: [CMAssetCollection] = []
    
    var pageControl: CMPickerViewController?
    
    /// 加载相册列表
    func loadAlbums() async {
        pageControl?.loading()
        print("Asset: 加载相册")
        do {
            let allAlbums = try await CMAssetManager.shared.getAlbums()
            await MainActor.run {
                albums = allAlbums
                if let firstAlbum = albums.first {
                    selectedAlbum = firstAlbum
                }
                pageControl?.showAssets()
                
                print("Asset: 相册数量__", albums.count)
                for item in allAlbums {
                    print("Asset:", item.title)
                }
            }
            
        } catch {
            await MainActor.run {
                pageControl?.showError("加载相册失败")
            }
            
        }
    }
}
