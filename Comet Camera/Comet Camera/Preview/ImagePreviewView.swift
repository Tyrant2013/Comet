//
//  ImagePreviewView.swift
//  Comet Camera
//

import SwiftUI
import Photos
import UIKit
import Asset

enum ImageSource {
    case camera
    case album
    case appInternal
}

struct ImagePreviewView: View {
    let image: UIImage
    let source: ImageSource
    let asset: CMAsset?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showEditView = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showShareSheet = false
    @State private var showActionSheet = false
    @State private var savedToAlbum = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(image: UIImage, source: ImageSource = .camera, asset: CMAsset? = nil) {
        self.image = image
        self.source = source
        self.asset = asset
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 图片显示,支持缩放和拖拽
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = value.translation
                            }
                            .onEnded { _ in
                                withAnimation {
                                    offset = .zero
                                }
                            }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            VStack {
                // 顶部工具栏
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // 底部操作栏
                HStack(spacing: 40) {
                    // 编辑按钮
                    Button(action: {
                        showEditView = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 22))
                            Text("编辑")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                    
                    // 分享按钮
                    Button(action: {
                        showShareSheet = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 22))
                            Text("分享")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                    
                    // 保存到相册按钮
                    Button(action: {
                        saveToPhotoLibrary()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 22))
                            Text("保存")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showEditView) {
            PhotoEditorEntryView(image: image, source: source, asset: asset)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("选项"),
                buttons: [
                    .default(Text("编辑")) {
                        showEditView = true
                    },
                    .default(Text("分享到...")) {
                        showShareSheet = true
                    },
                    .default(Text("保存到相册")) {
                        saveToPhotoLibrary()
                    },
                    .cancel()
                ]
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(savedToAlbum ? "保存成功" : "保存失败"), message: Text(alertMessage))
        }
    }
    
    private func saveToPhotoLibrary() {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    alertMessage = "请在设置中允许访问照片"
                    showAlert = true
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        savedToAlbum = true
                        alertMessage = "已保存到相册"
                    } else {
                        alertMessage = error?.localizedDescription ?? "保存失败"
                    }
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - 分享Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ImagePreviewView(image: UIImage(named: "PreviewImage")!, source: .album, asset: nil)
}
