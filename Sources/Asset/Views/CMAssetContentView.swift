//
//  SwiftUIView.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/20.
//

import SwiftUI
import Combine

struct CMAssetContentView: View {
    @ObservedObject var albumViewModel: CMAlbumViewModel
    @ObservedObject var assetViewModel: CMAssetPickerViewModel
    
    @State private var showAlbumList = false
    @State private var isMultiSelect = false
    @State private var selectedAssets: [CMAsset] = []
    var body: some View {
        VStack(spacing: 6) {
            // 顶部导航栏
            NavigationBar(
                title: albumViewModel.selectedAlbum?.title ?? "相册",
                showAlbumList: $showAlbumList,
                isMultiSelect: $isMultiSelect,
                selectedCount: selectedAssets.count,
                onDone: {}
            )
            
            // 内容区域
            ZStack {
                CMAssetGridView(
                    assetFetchResult: CMAssetManager.shared.assetFetchResult,
                    selectedAssets: $selectedAssets,
                    isMultiSelect: isMultiSelect,
                    onAssetTap: { asset, rect in
//                                previewStartFrame = rect
//                                if let index = assets.firstIndex(where: { $0.id == asset.id }) {
//                                    previewIndex = index
//                                }
//                                showPreview = true
                    }
                )
                .padding(.horizontal, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fullScreenCover(isPresented: $showAlbumList) {
            AlbumListView(
                albums: albumViewModel.albums,
                selectedAlbum: $albumViewModel.selectedAlbum,
                onSelectAlbum: { album in
                    albumViewModel.selectedAlbum = album
                    showAlbumList = false
                    Task {
                        await assetViewModel.loadAssets(in: album)
                    }
                }
            )
        }
    }
}

#Preview {
//    SwiftUIView()
}
