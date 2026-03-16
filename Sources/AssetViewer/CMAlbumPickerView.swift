//
//  CMAlbumPickerView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine

public struct CMAlbumPickerView: View {
    @ObservedObject private var albumManager: CMAlbumManager
    @Binding private var selectedAlbum: CMAlbum?
    @State private var isPresented: Bool = false
    @State private var showEditor: Bool = false
    @State private var editingAlbum: CMAlbum?
    
    private let showCreateButton: Bool
    private let allowEditing: Bool
    private let onAlbumSelected: (CMAlbum) -> Void
    
    public init(
        albumManager: CMAlbumManager = .shared,
        selectedAlbum: Binding<CMAlbum?>,
        showCreateButton: Bool = true,
        allowEditing: Bool = true,
        onAlbumSelected: @escaping (CMAlbum) -> Void = { _ in }
    ) {
        self.albumManager = albumManager
        self._selectedAlbum = selectedAlbum
        self.showCreateButton = showCreateButton
        self.allowEditing = allowEditing
        self.onAlbumSelected = onAlbumSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            currentAlbumButton
            
            if isPresented {
                albumListSheet
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
    
    @ViewBuilder
    private var currentAlbumButton: some View {
        Button(action: {
            withAnimation {
                isPresented.toggle()
            }
        }) {
            HStack(spacing: 12) {
                if let album = selectedAlbum {
                    albumThumbnail(for: album)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(album.assetCount) 张照片")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isPresented ? 180 : 0))
                } else {
                    Text("选择相册")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isPresented ? 180 : 0))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var albumListSheet: some View {
        VStack(spacing: 0) {
            sheetHeader
            
            if albumManager.isLoading {
                loadingView
            } else if albumManager.albums.isEmpty {
                emptyView
            } else {
                albumList
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .zIndex(1)
    }
    
    @ViewBuilder
    private var sheetHeader: some View {
        HStack(spacing: 16) {
            Text("相册")
                .font(.system(size: 20, weight: .bold))
            
            Spacer()
            
            if showCreateButton {
                Button(action: {
                    editingAlbum = nil
                    showEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var albumList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(albumManager.albums) { album in
                    albumRow(for: album)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectAlbum(album)
                        }
                }
            }
        }
        .frame(maxHeight: 400)
        .sheet(isPresented: $showEditor) {
            if let editingAlbum = editingAlbum {
                CMAlbumEditorView(
                    album: editingAlbum,
                    albumManager: albumManager
                )
            } else {
                CMAlbumEditorView(
                    albumManager: albumManager
                )
            }
        }
    }
    
    @ViewBuilder
    private func albumRow(for album: CMAlbum) -> some View {
        HStack(spacing: 12) {
            albumThumbnail(for: album)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("\(album.assetCount) 张照片")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if selectedAlbum?.id == album.id {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            if allowEditing && album.albumType == .userCreated {
                Button(action: {
                    editingAlbum = album
                    showEditor = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(selectedAlbum?.id == album.id ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    @ViewBuilder
    private func albumThumbnail(for album: CMAlbum) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
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
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载相册中...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: 400)
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("暂无相册")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: 400)
    }
    
    private func selectAlbum(_ album: CMAlbum) {
        selectedAlbum = album
        onAlbumSelected(album)
        
        withAnimation {
            isPresented = false
        }
    }
}

public extension CMAlbumPickerView {
    func refreshAlbums() {
        albumManager.fetchAllAlbums()
    }
}

struct CMAlbumPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CMAlbumPickerView(
            selectedAlbum: .constant(nil)
        )
    }
}
