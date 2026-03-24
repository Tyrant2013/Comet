import SwiftUI
import Photos

/// 图片预览视图
struct CMAssetPreviewView: View {
    /// 图片列表
//    @Binding var assets: [CMAsset]
    let fetchResult: CMFetchResult<PHAsset>
    /// 初始选中的图片索引
    let initialIndex: Int
    /// 选中的图片列表
    @Binding var selectedAssets: [CMAsset]
    /// 是否为多选模式
    let isMultiSelect: Bool
    /// 关闭回调
    let onDismiss: () -> Void
    /// 编辑回调（单选模式下）
    let onEdit: (CMAsset) -> Void
    /// 当前显示的图片索引
    @State private var currentIndex: Int
    /// 缩放比例
    @State private var scale: CGFloat = 1.0
    /// 偏移量
    @State private var offset: CGSize = .zero
    /// 是否正在拖动
    @State private var isDragging: Bool = false
    
    @Environment(\.dismiss) var dismiss
    @State private var showImageInfo = false
    init(
        assetFetchResult: CMFetchResult<PHAsset>,
        initialIndex: Int,
        selectedAssets: Binding<[CMAsset]>,
        isMultiSelect: Bool,
        onDismiss: @escaping () -> Void,
        onEdit: @escaping (CMAsset) -> Void
    ) {
//        self._assets = assets
        self.fetchResult = assetFetchResult
        self.initialIndex = initialIndex
        self._selectedAssets = selectedAssets
        self.isMultiSelect = isMultiSelect
        self.onDismiss = onDismiss
        self.onEdit = onEdit
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        CMPhotoBrowserView(fetchResult: fetchResult, index: $currentIndex)
    }
    
    /// 当前显示的图片
    private var currentAsset: CMAsset {
        let phAsset = fetchResult.object(at: currentIndex)
        return CMAsset(phAsset: phAsset!)
    }
    
    /// 切换选择状态
    private func toggleSelection() {
//        if selectedAssets.contains(currentAsset) {
//            selectedAssets.removeAll { $0.id == currentAsset.id }
//        } else {
//            selectedAssets.append(currentAsset)
//        }
    }
}

/// 单个图片预览项视图
struct CMAssetPreviewItemView: View {
    /// 图片资源
    let asset: CMAsset
    /// 缩放比例
    @Binding var scale: CGFloat
    /// 偏移量
    @Binding var offset: CGSize
    /// 是否正在拖动
    @Binding var isDragging: Bool
    /// 关闭回调
    let onDismiss: () -> Void
    /// 图片
    @State private var image: UIImage? = nil
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            if let image = asset.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
//                    .scaleEffect(scale)
//                    .offset(offset)
//                    .gesture(
//                        MagnificationGesture()
//                            .onChanged { value in
//                                scale = max(1.0, min(value, 3.0))
//                            }
//                    )
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                if scale > 1.0 {
//                                    offset = value.translation
//                                    isDragging = true
//                                }
//                            }
//                            .onEnded { _ in
//                                isDragging = false
//                            }
//                    )
//                    .simultaneousGesture(
//                        TapGesture(count: 2)
//                            .onEnded { _ in
//                                if scale > 1.0 {
//                                    withAnimation {
//                                        scale = 1.0
//                                        offset = .zero
//                                    }
//                                } else {
//                                    scale = 2.0
//                                }
//                            }
//                    )
            }
        }
//        .onAppear {
//            loadImage()
//        }
    }
    
    /// 加载图片
    private func loadImage() {
        Task {
            do {
                let loadedImage = try await CMAssetLoader.shared.loadOriginalImage(for: asset)
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            } catch {
                print("加载图片失败: \(error)")
            }
        }
    }
}

/// 预览
//struct CMAssetPreviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        CMAssetPreviewView(
//            assets: [],
//            initialIndex: 0,
//            selectedAssets: .constant([]),
//            isMultiSelect: true,
//            onDismiss: {},
//            onEdit: { _ in }
//        )
//    }
//}
