//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/20.
//

import Foundation
import Combine

final class CMAssetPickerViewModel: ObservableObject {
    @Published var viewState: CMAssetPickerViewState = .assets
    /// 选中的图片列表
    var selectedAssets: [CMAsset] = []
    /// 相册列表
    @Published private var albums: [CMAssetCollection] = []
    /// 当前选中的相册
    @Published private var selectedAlbum: CMAssetCollection?
    /// 是否显示相册列表
    @Published private var showAlbumList: Bool = true
    /// 是否为多选模式
    @Published var isMultiselect: Bool = false
    init() {
        requestPermission()
    }
    
    /// 请求权限
    func requestPermission() {
        Task {
            let hasPermission = await CMAssetManager.shared.requestPermission()
            if !hasPermission {
                viewState = .noPermission
            }
        }
    }
    
    /// 加载相册中的图片
    /// - Parameter album: 相册
    func loadAssets(in album: CMAssetCollection) async {
        print("load:", album.title)
        await MainActor.run {
            viewState = .loading
        }
        
        do {
            try await CMAssetManager.shared.getAssets(in: album)
            await MainActor.run {
                viewState = .assets
            }
            
        } catch {
            await MainActor.run {
                viewState = .error(message: "加载图片失败")
            }
        }
    }
}
