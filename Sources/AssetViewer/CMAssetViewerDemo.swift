//
//  CMAssetViewerDemo.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine

public struct CMAssetViewerDemo: View {
    @StateObject private var albumManager = CMAlbumManager.shared
    @State private var selectedAssets: [CMAsset] = []
    @State private var showPreview: Bool = false
    @State private var previewAssets: [CMAsset] = []
    @State private var initialPreviewIndex: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                if albumManager.authorizationStatus == .authorized {
                    mainContent
                } else {
                    permissionView
                }
            }
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        CMAssetViewerView(
            albumManager: albumManager,
            onAssetSelected: { asset in
                handleAssetSelected(asset)
            },
            onAssetsSelected: { assets in
                handleAssetsSelected(assets)
            }
        )
        .sheet(isPresented: $showPreview) {
            CMAssetPreviewView(
                assets: previewAssets,
                initialIndex: initialPreviewIndex,
                onDismiss: { index in
                    handlePreviewDismiss(index)
                }
            )
        }
    }
    
    @ViewBuilder
    private var permissionView: some View {
        CMPermissionView(
            title: "需要相册访问权限",
            message: "为了浏览和管理您的照片，我们需要访问您的相册。",
            iconName: "photo.on.rectangle.angled",
            onAuthorized: {
                albumManager.fetchAllAlbums()
            }
        )
    }
    
    private func handleAssetSelected(_ asset: CMAsset) {
        guard let album = albumManager.albums.first else { return }
        
        let assets = album.getAssets()
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            previewAssets = assets
            initialPreviewIndex = index
            showPreview = true
        }
    }
    
    private func handleAssetsSelected(_ assets: [CMAsset]) {
        selectedAssets = assets
        
        if assets.count == 1 {
            handleAssetSelected(assets[0])
        } else {
            print("Selected \(assets.count) assets")
        }
    }
    
    private func handlePreviewDismiss(_ index: Int) {
        showPreview = false
    }
}

public struct CMAssetViewerSimpleDemo: View {
    @StateObject private var albumManager = CMAlbumManager.shared
    @State private var selectedAlbum: CMAlbum?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            
            if let album = selectedAlbum {
                albumContent(album)
            } else {
                emptyState
            }
        }
        .onAppear {
            setup()
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack {
            Text("相册")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: refreshAlbums) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private func albumContent(_ album: CMAlbum) -> some View {
        CMAssetGridView(
            assets: album.getAssets(),
            columns: 3,
            onAssetTap: { asset in
                print("Tapped asset: \(asset.id)")
            }
        )
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("选择一个相册")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !albumManager.albums.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(albumManager.albums) { album in
                            Button(action: {
                                selectedAlbum = album
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(album.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("\(album.assetCount) 张照片")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func setup() {
        albumManager.checkAuthorizationStatus()
        
        if albumManager.authorizationStatus == .authorized {
            albumManager.fetchAllAlbums()
        }
    }
    
    private func refreshAlbums() {
        albumManager.fetchAllAlbums()
    }
}

public struct CMAssetViewerAdvancedDemo: View {
    @StateObject private var albumManager = CMAlbumManager.shared
    @State private var selectedAlbum: CMAlbum?
    @State private var selectedAssets: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var showPreview: Bool = false
    @State private var showAlbumEditor: Bool = false
    @State private var previewAssets: [CMAsset] = []
    @State private var initialPreviewIndex: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    toolbar
                    
                    if let album = selectedAlbum {
                        content(album)
                    } else {
                        albumList
                    }
                }
            }
            .sheet(isPresented: $showPreview) {
                CMAssetPreviewView(
                    assets: previewAssets,
                    initialIndex: initialPreviewIndex
                )
            }
            .sheet(isPresented: $showAlbumEditor) {
                CMAlbumEditorView(
                    albumManager: albumManager
                ) { album in
                    if let album = album {
                        selectedAlbum = album
                    }
                    showAlbumEditor = false
                }
            }
        }
    }
    
    @ViewBuilder
    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("相册")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showAlbumEditor = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }
            .padding()
            
            if isSelectionMode {
                selectionToolbar
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var selectionToolbar: some View {
        HStack {
            Button("取消") {
                cancelSelection()
            }
            .foregroundColor(.blue)
            
            Spacer()
            
            Text("已选择 \(selectedAssets.count) 项")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("完成") {
                completeSelection()
            }
            .foregroundColor(.blue)
            .disabled(selectedAssets.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    @ViewBuilder
    private func content(_ album: CMAlbum) -> some View {
        CMAssetGridView(
            assets: album.getAssets(),
            columns: 3,
            onAssetTap: { asset in
                handleAssetTap(asset)
            },
            onSelectionChanged: { assets in
                handleSelectionChanged(assets)
            }
        )
    }
    
    @ViewBuilder
    private var albumList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(albumManager.albums) { album in
                    Button(action: {
                        selectedAlbum = album
                    }) {
                        HStack(spacing: 12) {
                            albumThumbnail(album)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("\(album.assetCount) 张照片")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func albumThumbnail(_ album: CMAlbum) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            
            if let coverImage = album.coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func handleAssetTap(_ asset: CMAsset) {
        if isSelectionMode {
            toggleSelection(asset)
        } else {
            showPreview(for: asset)
        }
    }
    
    private func handleSelectionChanged(_ assets: [CMAsset]) {
        selectedAssets = Set(assets.map { $0.id })
        isSelectionMode = !selectedAssets.isEmpty
    }
    
    private func toggleSelection(_ asset: CMAsset) {
        if selectedAssets.contains(asset.id) {
            selectedAssets.remove(asset.id)
        } else {
            selectedAssets.insert(asset.id)
        }
        
        isSelectionMode = !selectedAssets.isEmpty
    }
    
    private func cancelSelection() {
        selectedAssets.removeAll()
        isSelectionMode = false
    }
    
    private func completeSelection() {
        print("Selected \(selectedAssets.count) assets")
        cancelSelection()
    }
    
    private func showPreview(for asset: CMAsset) {
        guard let album = selectedAlbum else { return }
        
        let assets = album.getAssets()
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            previewAssets = assets
            initialPreviewIndex = index
            showPreview = true
        }
    }
    
    private func refresh() {
        albumManager.fetchAllAlbums()
    }
}

struct CMAssetViewerDemo_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CMAssetViewerDemo()
                .previewDisplayName("Full Demo")
            
            CMAssetViewerSimpleDemo()
                .previewDisplayName("Simple Demo")
            
            CMAssetViewerAdvancedDemo()
                .previewDisplayName("Advanced Demo")
        }
    }
}
