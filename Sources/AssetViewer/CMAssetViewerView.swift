//
//  CMAssetViewerView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine

public struct CMAssetViewerView: View {
    @ObservedObject private var viewModel: CMAssetViewerViewModel
    @ObservedObject private var albumManager: CMAlbumManager
    
    @State private var selectedAlbum: CMAlbum?
    @State private var selectedAssets: Set<String> = []
    @State private var isSelectionMode: Bool = false
    @State private var showAlbumEditor: Bool = false
    
    private let onAssetSelected: (CMAsset) -> Void
    private let onAssetsSelected: ([CMAsset]) -> Void
    
    public init(
        albumManager: CMAlbumManager = .shared,
        onAssetSelected: @escaping (CMAsset) -> Void = { _ in },
        onAssetsSelected: @escaping ([CMAsset]) -> Void = { _ in }
    ) {
        self.albumManager = albumManager
        self.viewModel = CMAssetViewerViewModel(albumManager: albumManager)
        self.onAssetSelected = onAssetSelected
        self.onAssetsSelected = onAssetsSelected
    }
    
    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                if let album = selectedAlbum {
                    contentView(for: album)
                } else {
                    emptyAlbumView
                }
            }
        }
        .onAppear {
            setupView()
        }
        .sheet(isPresented: $showAlbumEditor) {
            CMAlbumEditorView(
                albumManager: albumManager
            ) { album in
                if let album = album {
                    selectedAlbum = album
                }
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 0) {
            CMAlbumPickerView(
                albumManager: albumManager,
                selectedAlbum: $selectedAlbum,
                showCreateButton: true,
                allowEditing: true
            ) { album in
                handleAlbumSelected(album)
            }
            
            Divider()
            
            if isSelectionMode {
                selectionToolbar
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var selectionToolbar: some View {
        HStack(spacing: 16) {
            Button(action: cancelSelection) {
                Text("取消")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Text("已选择 \(selectedAssets.count) 项")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if !selectedAssets.isEmpty {
                Button(action: handleSelectionComplete) {
                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private func contentView(for album: CMAlbum) -> some View {
        CMAssetGridView(
            assets: viewModel.assets,
            columns: 3,
            cellSpacing: 2,
            onAssetTap: { asset in
                handleAssetTap(asset)
            },
            onSelectionChanged: { assets in
                handleSelectionChanged(assets)
            }
        )
    }
    
    @ViewBuilder
    private var emptyAlbumView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("选择一个相册开始浏览")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            if albumManager.authorizationStatus != .authorized {
                Button(action: requestAuthorization) {
                    Text("授权访问相册")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func setupView() {
        albumManager.checkAuthorizationStatus()
        
        if albumManager.authorizationStatus == .authorized {
            albumManager.fetchAllAlbums()
            
            if albumManager.albums.isEmpty {
                return
            }
            
            if selectedAlbum == nil {
                selectedAlbum = albumManager.albums.first
            }
        }
    }
    
    private func handleAlbumSelected(_ album: CMAlbum) {
        selectedAlbum = album
        viewModel.loadAssets(from: album)
        cancelSelection()
    }
    
    private func handleAssetTap(_ asset: CMAsset) {
        if isSelectionMode {
            toggleSelection(for: asset)
        } else {
            onAssetSelected(asset)
        }
    }
    
    private func handleSelectionChanged(_ assets: [CMAsset]) {
        selectedAssets = Set(assets.map { $0.id })
        isSelectionMode = !selectedAssets.isEmpty
    }
    
    private func toggleSelection(for asset: CMAsset) {
        if selectedAssets.contains(asset.id) {
            selectedAssets.remove(asset.id)
        } else {
            selectedAssets.insert(asset.id)
        }
        
        isSelectionMode = !selectedAssets.isEmpty
        
        if !isSelectionMode {
            onAssetsSelected([])
        }
    }
    
    private func cancelSelection() {
        selectedAssets.removeAll()
        isSelectionMode = false
        onAssetsSelected([])
    }
    
    private func handleSelectionComplete() {
        let selected = viewModel.assets.filter { selectedAssets.contains($0.id) }
        onAssetsSelected(selected)
        cancelSelection()
    }
    
    private func requestAuthorization() {
        albumManager.requestAuthorization { status in
            if status == .authorized {
                albumManager.fetchAllAlbums()
            }
        }
    }
    
    public func refresh() {
        if let album = selectedAlbum {
            viewModel.loadAssets(from: album)
        }
    }
}

public final class CMAssetViewerViewModel: ObservableObject {
    @Published public var assets: [CMAsset] = []
    @Published public var isLoading: Bool = false
    
    private let albumManager: CMAlbumManager
    private var currentAlbum: CMAlbum?
    private var cancellables = Set<AnyCancellable>()
    
    public init(albumManager: CMAlbumManager = .shared) {
        self.albumManager = albumManager
        setupBindings()
    }
    
    private func setupBindings() {
        albumManager.$albums
            .sink { [weak self] albums in
                self?.handleAlbumsUpdate(albums)
            }
            .store(in: &cancellables)
    }
    
    private func handleAlbumsUpdate(_ albums: [CMAlbum]) {
        guard let currentAlbum = currentAlbum else { return }
        
        if let updatedAlbum = albums.first(where: { $0.id == currentAlbum.id }) {
            self.currentAlbum = updatedAlbum
        }
    }
    
    public func loadAssets(from album: CMAlbum) {
        currentAlbum = album
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let assets = album.getAssets()
            
            DispatchQueue.main.async {
                self.assets = assets
                self.isLoading = false
            }
        }
    }
    
    public func loadMoreAssets(limit: Int = 50) {
        guard let album = currentAlbum else { return }
        
        let currentCount = assets.count
        let newAssets = album.getAssets(limit: limit)
        
        if newAssets.count > currentCount {
            assets = newAssets
        }
    }
}

public extension CMAssetViewerView {
    func selectAlbum(_ album: CMAlbum) {
        selectedAlbum = album
        viewModel.loadAssets(from: album)
    }
    
    func getSelectedAssets() -> [CMAsset] {
        viewModel.assets.filter { selectedAssets.contains($0.id) }
    }
}

struct CMAssetViewerView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetViewerView()
    }
}
