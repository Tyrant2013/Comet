//
//  SavedPhotosView.swift
//  Comet Camera
//

import SwiftUI

struct SavedPhotosView: View {
    @State private var photos: [SavedPhoto] = []
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPhoto: SavedPhoto?
    @State private var showPreview = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if photos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无保存的照片")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("编辑照片后点击完成即可保存到这里")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 2) {
                            ForEach(photos, id: \.id) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                        showPreview = true
                                    }
                            }
                        }
                    }
                    .refreshable {
                        await loadPhotos()
                    }
                }
            }
            .navigationTitle("我的照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let photo = selectedPhoto, let image = photo.image {
                ImagePreviewView(image: image, source: .appInternal, asset: nil)
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("错误"), message: Text(errorMessage))
        }
        .onAppear {
            Task {
                await loadPhotos()
            }
        }
    }
    
    private func loadPhotos() async {
        do {
            let loadedPhotos = try await PhotoStorageService.shared.fetchPhotos(limit: 100)
            await MainActor.run {
                photos = loadedPhotos
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: SavedPhoto
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumbnail = photo.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
            }
            
            // 如果有编辑元数据，显示编辑图标
            if photo.editMetadata != nil && !photo.editMetadata!.isEmpty {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(4)
            }
        }
    }
}

#Preview {
    SavedPhotosView()
}
