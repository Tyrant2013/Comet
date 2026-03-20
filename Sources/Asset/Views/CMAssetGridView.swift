import SwiftUI
import Photos

/// 图片网格视图
struct CMAssetGridView: View {
    /// 图片列表
//    let assets: [CMAsset]
    let assetFetchResult: CMFetchResult<PHAsset>
    /// 选中的图片列表
    @Binding var selectedAssets: [CMAsset]
    /// 是否为多选模式
    let isMultiSelect: Bool
    /// 图片点击回调
    let onAssetTap: (CMAsset, CGRect) -> Void
    /// 列数
    let columns: Int = 3
    
    var spacing: CGFloat = 1
    var body: some View {
        GeometryReader { reader in
            let gridWidth = reader.size.width - CGFloat(columns - 1) * spacing
            let gridItemSize = gridWidth / CGFloat(columns)
            let itemHeight = gridItemSize
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(gridItemSize), spacing: spacing), count: columns), spacing: 1) {
                ForEach((0..<assetFetchResult.count).enumerated(), id: \.offset) { index, _ in
                    if let obj = assetFetchResult.object(at: index) {
                        let asset = CMAsset(phAsset: obj)
                        CMAssetItemView(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset),
                            isMultiSelect: isMultiSelect,
                            onTap: { rect in
                                onAssetTap(asset, rect)
                            }
                        )
                        .frame(width: gridItemSize, height: itemHeight)
                        .clipShape(Rectangle())
                    }
                }
            }
        }
        .background(Color.white)
    }
}

/// 单个图片项视图
struct CMAssetItemView: View {
    /// 图片资源
    let asset: CMAsset
    /// 是否被选中
    let isSelected: Bool
    /// 是否为多选模式
    let isMultiSelect: Bool
    /// 点击回调
    let onTap: (CGRect) -> Void
    /// 图片加载状态
    @State private var image: UIImage? = nil
    @State private var isLoading: Bool = true
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .hero(id: asset.id)
            } else {
                Color.gray.opacity(0.3)
            }
            
            if isMultiSelect {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.white, lineWidth: 2)
                            .background(isSelected ? Color.blue : Color.clear)
                            .frame(width: 24, height: 24)
                            .padding(4)
                            .overlay(
                                Group {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                },
                                alignment: .center
                            )
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 获取视图在屏幕上的位置
            let window: UIWindow?
            if #available(iOS 15, *) {
                window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first
            }
            else {
                window = UIApplication.shared.windows.first
            }
            let rect = window?.convert(bounds, from: UIView()) ?? .zero
            onTap(rect)
        }
        .onAppear {
            loadImage()
        }
    }
    
    /// 加载图片
    private func loadImage() {
        let targetSize = CGSize(width: 200, height: 200)
        CMAssetLoader.shared.loadImage(
            for: asset,
            targetSize: targetSize
        ) { loadedImage, error in
            if let loadedImage = loadedImage {
                DispatchQueue.main.async {
                    self.image = loadedImage
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 获取视图边界
    private var bounds: CGRect {
        return CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width / CGFloat(3), height: UIScreen.main.bounds.width / CGFloat(3))
    }
}

/// 预览
struct CMAssetGridView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetGridView(
            assetFetchResult: CMFetchResult(result: PHFetchResult<PHAsset>()),
            selectedAssets: .constant([]),
            isMultiSelect: true,
            onAssetTap: { _, _ in }
        )
    }
}
