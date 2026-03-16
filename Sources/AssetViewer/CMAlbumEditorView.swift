//
//  CMAlbumEditorView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine

public struct CMAlbumEditorView: View {
    @ObservedObject private var albumManager: CMAlbumManager
    @ObservedObject private var viewModel: CMAlbumEditorViewModel
    
    @Environment(\.presentationMode) private var presentationMode
    
    private let album: CMAlbum?
    private let onComplete: ((CMAlbum?) -> Void)
    
    public init(
        album: CMAlbum? = nil,
        albumManager: CMAlbumManager = .shared,
        onComplete: @escaping (CMAlbum?) -> Void = { _ in }
    ) {
        self.album = album
        self.albumManager = albumManager
        self.onComplete = onComplete
        self.viewModel = CMAlbumEditorViewModel(album: album)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                content
            }
            .navigationTitle(viewModel.isEditing ? "编辑相册" : "新建相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        handleComplete()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        Form {
            Section(header: Text("相册信息")) {
                TextField("相册名称", text: $viewModel.albumName)
                
                if let album = album {
                    HStack {
                        Text("照片数量")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(album.assetCount)")
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("创建时间")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let startDate = album.startDate {
                            Text(formatDate(startDate))
                                .foregroundColor(.primary)
                        } else {
                            Text("未知")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if viewModel.isEditing, let album = album, album.albumType == .userCreated {
                Section(header: Text("操作"), footer: Text("删除相册将同时删除其中的所有照片")) {
                    Button(action: {
                        viewModel.showDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            
                            Text("删除相册")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .alert(isPresented: $viewModel.showDeleteAlert) {
            Alert(
                title: Text("删除相册"),
                message: Text("确定要删除这个相册吗？此操作不可撤销。"),
                primaryButton: .cancel(Text("取消")) {
                    viewModel.showDeleteAlert = false
                },
                secondaryButton: .destructive(Text("删除")) {
                    deleteAlbum()
                }
            )
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("提示"),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text("确定")) {
                    viewModel.showError = false
                }
            )
        }
    }
    
    private func handleComplete() {
        viewModel.isLoading = true
        
        if viewModel.isEditing, let album = album {
            updateAlbum(album)
        } else {
            createAlbum()
        }
    }
    
    private func createAlbum() {
        albumManager.createAlbum(name: viewModel.albumName) { result in
            DispatchQueue.main.async {
                viewModel.isLoading = false
                
                switch result {
                case .success(let album):
                    onComplete(album)
                    dismiss()
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
    }
    
    private func updateAlbum(_ album: CMAlbum) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            viewModel.isLoading = false
            onComplete(album)
            dismiss()
        }
    }
    
    private func deleteAlbum() {
        guard let album = album else { return }
        
        viewModel.isLoading = true
        
        albumManager.deleteAlbum(album: album) { result in
            DispatchQueue.main.async {
                viewModel.isLoading = false
                viewModel.showDeleteAlert = false
                
                switch result {
                case .success:
                    onComplete(nil)
                    dismiss()
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
    }
    
    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

public final class CMAlbumEditorViewModel: ObservableObject {
    @Published public var albumName: String = ""
    @Published public var isLoading: Bool = false
    @Published public var showDeleteAlert: Bool = false
    @Published public var showError: Bool = false
    @Published public var errorMessage: String = ""
    
    public let isEditing: Bool
    private let album: CMAlbum?
    
    public init(album: CMAlbum? = nil) {
        self.album = album
        self.isEditing = album != nil
        
        if let album = album {
            self.albumName = album.title
        }
    }
    
    public var isValid: Bool {
        !albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public extension CMAlbumEditorView {
    static func createSheet(
        albumManager: CMAlbumManager = .shared,
        onComplete: @escaping (CMAlbum?) -> Void = { _ in }
    ) -> some View {
        CMAlbumEditorView(
            albumManager: albumManager,
            onComplete: onComplete
        )
    }
    
    static func editSheet(
        album: CMAlbum,
        albumManager: CMAlbumManager = .shared,
        onComplete: @escaping (CMAlbum?) -> Void = { _ in }
    ) -> some View {
        CMAlbumEditorView(
            album: album,
            albumManager: albumManager,
            onComplete: onComplete
        )
    }
}

struct CMAlbumEditorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CMAlbumEditorView(
                album: nil
            )
        }
    }
}
