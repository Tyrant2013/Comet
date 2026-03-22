import SwiftUI



/// 相册选择器主视图
public struct CMAssetPickerView: View {
    @StateObject var pageControl = CMPickerViewController()
    @StateObject var albumViewModel: CMAlbumViewModel = CMAlbumViewModel()
    @StateObject var viewModel: CMAssetPickerViewModel = CMAssetPickerViewModel()
    /// 选中的图片列表
//    @Binding var selectedAssets: [CMAsset]
    /// 是否为多选模式
    @State private var isMultiSelect: Bool = false
    /// 相册列表
    @State private var albums: [CMAssetCollection] = []
    /// 当前选中的相册
    @State private var selectedAlbum: CMAssetCollection?
    /// 图片列表
    @State private var assets: [CMAsset] = []
    /// 预览的图片索引
    @State private var previewIndex: Int = 0
    /// 是否显示编辑视图
    @State private var showEditView: Bool = false
    /// 当前编辑的图片
    @State private var currentEditAsset: CMAsset? = nil
    /// 加载状态
    @State private var isLoading: Bool = true
    /// 权限状态
    @State private var hasPermission: Bool = false
    /// 错误信息
    @State private var errorMessage: String? = nil
    /// 预览动画的起始帧
    @State private var previewStartFrame: CGRect = .zero
    
    public init() { }
    
    public var body: some View {
        
        ZStack {
            switch pageControl.viewState {
            case .noPermission:
                PermissionView {
                    viewModel.requestPermission()
                }
            case .error(let message):
                ErrorView(message: message) {
                    Task {
                        await albumViewModel.loadAlbums()
                    }
                }
            case .loading:
                LoadingView()
            case .assets:
                VStack(spacing: 0) {
                    // 顶部导航栏
                    NavigationBar(
                        title: selectedAlbum?.title ?? "相册",
                        showAlbumList: $pageControl.showAlbumList,
                        isMultiSelect: $isMultiSelect,
                        selectedCount: viewModel.selectedAssets.count,
                        onDone: {}
                    )
                    
                    // 内容区域
                    CMAssetGridView(
                        assetFetchResult: CMAssetManager.shared.assetFetchResult,
                        selectedAssets: $viewModel.selectedAssets,
                        isMultiSelect: isMultiSelect,
                        onAssetTap: { asset, rect in
                            pageControl.showPreview = true
                        }
                    )
                    .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .fullScreenCover(isPresented: $pageControl.showAlbumList, content: {
                    AlbumListView(
                        albums: albumViewModel.albums,
                        selectedAlbum: $albumViewModel.selectedAlbum,
                        onSelectAlbum: { album in
                            albumViewModel.selectedAlbum = album
                            pageControl.showAlbumList = false
                            Task {
                                await viewModel.loadAssets(in: album)
                            }
                        }
                    )
                })
                .fullScreenCover(isPresented: .init(get: {
                    if showEditView , let asset = currentEditAsset {
                        return true
                    }
                    return false
                }, set: { _ in
                    showEditView = false
                }), content: {
                    HeroAnimationContainer(isVisible: $showEditView) {
                        CMAssetDetailView(
                            asset: currentEditAsset!,
                            onDismiss: { showEditView = false },
                            onSave: { editedAsset in
                                showEditView = false
                                // 这里可以添加保存逻辑
                            }
                        )
                    }
                })
                .onAppear {
                    Task {
                        await albumViewModel.loadAlbums()
                        if let album = albumViewModel.albums.first {
                            await viewModel.loadAssets(in: album)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        // 预览和编辑视图
        .fullScreenCover(isPresented: $pageControl.showPreview) {
            HeroAnimationContainer(isVisible: $pageControl.showPreview) {
                CMAssetPreviewView(
//                    assets: $assets,
                    assetFetchResult: CMAssetManager.shared.assetFetchResult,
                    initialIndex: previewIndex,
                    selectedAssets: $viewModel.selectedAssets,
                    isMultiSelect: isMultiSelect,
                    onDismiss: { pageControl.showPreview = false },
                    onEdit: { asset in
                        pageControl.showPreview = false
                        currentEditAsset = asset
                        showEditView = true
                    }
                )
            }
        }
    }
}

/// 导航栏
struct NavigationBar: View {
    /// 标题
    let title: String
    /// 是否显示相册列表
    @Binding var showAlbumList: Bool
    /// 是否为多选模式
    @Binding var isMultiSelect: Bool
    /// 选中的数量
    let selectedCount: Int
    /// 完成回调
    let onDone: () -> Void
    
    
    @Environment(\.dismiss) var dismiss
    var body: some View {
        Button(action: { showAlbumList.toggle() }) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            Image(systemName: "chevron.down")
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .overlay(
            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                if isMultiSelect {
                    Text("已选择 \(selectedCount) 项")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Button(action: { isMultiSelect.toggle() }) {
                    Text(isMultiSelect ? "取消" : "选择")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(.leading, 16)
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 44)
        .background(Color.white)
//        .shadow(radius: 2)
    }
}

/// 相册列表视图
struct AlbumListView: View {
    /// 相册列表
    let albums: [CMAssetCollection]
    /// 当前选中的相册
    @Binding var selectedAlbum: CMAssetCollection?
    /// 选择相册回调
    let onSelectAlbum: (CMAssetCollection) -> Void
    
    var body: some View {
        List {
            ForEach(albums) { album in
                HStack {
                    Text(album.title)
                        .font(.system(size: 16))
                    Spacer()
                    Text("\(album.assetCount)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectAlbum(album)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

/// 权限视图
struct PermissionView: View {
    /// 权限请求回调
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("需要访问相册权限")
                .font(.system(size: 18, weight: .semibold))
            Text("请允许访问您的相册以选择图片")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onRequestPermission) {
                Text("允许访问")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

/// 错误视图
struct ErrorView: View {
    /// 错误信息
    let message: String
    /// 重试回调
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.red)
            Text("出错了")
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onRetry) {
                Text("重试")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}

/// 加载视图
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 16)
        }
    }
}

/// 预览
struct CMAssetPickerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CMAssetPickerView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange.ignoresSafeArea())
    }
}
