//
//  File.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/20.
//

import Foundation
import Combine

enum CMAssetPickerViewState {
    case noPermission
    case error(message: String)
    case loading
    case assets
}

final class CMPickerViewController: ObservableObject {
    @Published var viewState: CMAssetPickerViewState = .assets
    /// 是否显示相册列表
    @Published var showAlbumList: Bool = true
    /// 是否显示预览
    @Published var showPreview: Bool = false
    
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
    
    func loading() {
        viewState = .loading
    }
    
    func showError(_ message: String) {
        viewState = .error(message: message)
    }
    
    func showAlbumPicker() {
        
    }
    
    func showAssets() {
        viewState = .assets
    }
}
