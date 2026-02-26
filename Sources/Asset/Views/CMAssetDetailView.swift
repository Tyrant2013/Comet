import SwiftUI
import CoreImage
import PhotoEditor
import Photos

/// 单个图片编辑视图
struct CMAssetDetailView: View {
    /// 图片资源
    let asset: CMAsset
    /// 关闭回调
    let onDismiss: () -> Void
    /// 保存回调
    let onSave: (CMAsset) -> Void
    /// 图片
    @State private var image: UIImage? = nil
    /// 编辑后的图片
    @State private var editedImage: UIImage? = nil
    /// 加载状态
    @State private var isLoading: Bool = true
    /// 编辑操作
    @State private var operations: [CMPhotoEditOperation] = []
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // 图片显示区域
                if let editedImage = editedImage {
                    Image(uiImage: editedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.gray.opacity(0.3)
                }
                
                // 编辑工具栏
                EditToolbar(
                    operations: $operations,
                    onApply: applyEdits,
                    onReset: resetEdits
                )
            }
            
            // 顶部导航栏
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: saveImage) {
                        Text("保存")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                            .padding()
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    /// 加载图片
    private func loadImage() {
        Task {
            do {
                let loadedImage = try await CMAssetLoader.shared.loadOriginalImage(for: asset)
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.editedImage = loadedImage
                    self.isLoading = false
                }
            } catch {
                print("加载图片失败: \(error)")
            }
        }
    }
    
    /// 应用编辑
    private func applyEdits() {
        guard let image = image else { return }
        
        Task {
            do {
                guard let ciImage = CIImage(image: image) else { return }
                let editedCI = try CMPhotoEditor.edit(ciImage, operations: operations)
                
                let editedUIImage = UIImage(ciImage: editedCI)
                DispatchQueue.main.async {
                    self.editedImage = editedUIImage
                }
            } catch {
                print("编辑图片失败: \(error)")
            }
        }
    }
    
    /// 重置编辑
    private func resetEdits() {
        operations = []
        editedImage = image
    }
    
    /// 保存图片
    private func saveImage() {
        // 这里可以实现保存图片到相册的逻辑
        onSave(asset)
    }
}

/// 编辑工具栏
struct EditToolbar: View {
    /// 编辑操作
    @Binding var operations: [CMPhotoEditOperation]
    /// 应用编辑回调
    let onApply: () -> Void
    /// 重置编辑回调
    let onReset: () -> Void
    
    var body: some View {
        VStack {
            // 编辑工具选项
            HStack {
                Button(action: addFilter) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                Button(action: addCrop) {
                    Image(systemName: "crop")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                Button(action: addText) {
                    Image(systemName: "text.insert")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                Button(action: addMosaic) {
                    Image(systemName: "square.grid.2x2")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(Color.black.opacity(0.5))
            
            // 操作按钮
            HStack {
                Button(action: onReset) {
                    Text("重置")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding()
                }
                
                Spacer()
                
                Button(action: onApply) {
                    Text("应用")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                        .padding()
                }
            }
            .background(Color.black.opacity(0.8))
        }
    }
    
    /// 添加滤镜
    private func addFilter() {
        let filter = CMFilterOperation(filter: .chrome)
        operations.append(filter)
    }
    
    /// 添加裁剪
    private func addCrop() {
        let cropState = CMCropState(imageSize: CGSize(width: 1000, height: 1000), outputAspectRatio: 1.0)
        let crop = CMCropOperation(state: cropState)
        operations.append(crop)
    }
    
    /// 添加文本
    private func addText() {
        let config = CMTextOverlayOperation.Configuration(text: "Hello", normalizedOrigin: CGPoint(x: 0.5, y: 0.5), fontSize: 30)
        let text = CMTextOverlayOperation(configuration: config)
        operations.append(text)
    }
    
    /// 添加马赛克
    private func addMosaic() {
        let config = CMMosaicOperation.Configuration(manualRegions: [CGRect(x: 200, y: 200, width: 600, height: 600)], mosaicScale: 24)
        let mosaic = CMMosaicOperation(configuration: config)
        operations.append(mosaic)
    }
}

/// 预览
struct CMAssetDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetDetailView(
            asset: CMAsset(phAsset: PHAsset()),
            onDismiss: {},
            onSave: { _ in }
        )
    }
}
