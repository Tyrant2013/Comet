import SwiftUI
import Asset

/// 图片预览视图
struct CMAssetPreviewView: View {
    /// 图片列表
    @Binding var assets: [CMAsset]
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
    
    init(
        assets: Binding<[CMAsset]>,
        initialIndex: Int,
        selectedAssets: Binding<[CMAsset]>,
        isMultiSelect: Bool,
        onDismiss: @escaping () -> Void,
        onEdit: @escaping (CMAsset) -> Void
    ) {
        self._assets = assets
        self.initialIndex = initialIndex
        self._selectedAssets = selectedAssets
        self.isMultiSelect = isMultiSelect
        self.onDismiss = onDismiss
        self.onEdit = onEdit
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                TabView(selection: $currentIndex) {
                    ForEach(assets.indices, id: \.self) { index in
                        CMAssetPreviewItemView(
                            asset: assets[index],
                            scale: $scale,
                            offset: $offset,
                            isDragging: $isDragging,
                            onDismiss: onDismiss
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .gesture(
                    DragGesture(minimumDistance: 50, coordinateSpace: .global)
                        .onEnded { value in
                            if scale == 1.0 {
                                if value.translation.height > 100 {
                                    onDismiss()
                                }
                            }
                        }
                )
            }
            
            // 顶部工具栏
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .padding()
                    }
                    
                    Spacer()
                    
                    if isMultiSelect {
                        Button(action: toggleSelection) {
                            ZStack {
                                Circle()
                                    .stroke(selectedAssets.contains(currentAsset) ? Color.blue : Color.white, lineWidth: 2)
                                    .background(selectedAssets.contains(currentAsset) ? Color.blue : Color.clear)
                                    .frame(width: 32, height: 32)
                                
                                if selectedAssets.contains(currentAsset) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                            .padding()
                        }
                    } else {
                        Button(action: { onEdit(currentAsset) }) {
                            Image(systemName: "edit")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                                .padding()
                        }
                    }
                }
                
                Spacer()
            }
            
            // 底部页码
            VStack {
                Spacer()
                
                if assets.count > 1 {
                    Text("\(currentIndex + 1)/\(assets.count)")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .padding()
                }
            }
        }
        .onReceive([currentIndex].publisher) { _ in
            // 重置缩放和偏移
            scale = 1.0
            offset = .zero
        }
    }
    
    /// 当前显示的图片
    private var currentAsset: CMAsset {
        return assets[currentIndex]
    }
    
    /// 切换选择状态
    private func toggleSelection() {
        if selectedAssets.contains(currentAsset) {
            selectedAssets.removeAll { $0.id == currentAsset.id }
        } else {
            selectedAssets.append(currentAsset)
        }
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
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .hero(id: asset.id)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, min(value, 3.0))
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = value.translation
                                    isDragging = true
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded { _ in
                                if scale > 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                } else {
                                    scale = 2.0
                                }
                            }
                    )
            } else {
                Color.gray.opacity(0.3)
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
                }
            } catch {
                print("加载图片失败: \(error)")
            }
        }
    }
}

/// 预览
struct CMAssetPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetPreviewView(
            assets: [],
            initialIndex: 0,
            selectedAssets: .constant([]),
            isMultiSelect: true,
            onDismiss: {},
            onEdit: { _ in }
        )
    }
}