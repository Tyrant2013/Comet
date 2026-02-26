import SwiftUI
import Asset

/// 相册选择器主视图
struct CMAssetPickerView: View {
    /// 选中的图片列表
    @Binding var selectedAssets: [CMAsset]
    /// 是否为多选模式
    @State private var isMultiSelect: Bool = false
    /// 相册列表
    @State private var albums: [CMAssetCollection] = []
    /// 当前选中的相册
    @State private var selectedAlbum: CMAssetCollection?
    /// 图片列表
    @State private var assets: [CMAsset] = []
    /// 是否显示相册列表
    @State private var showAlbumList: Bool = true
    /// 是否显示预览
    @State private var showPreview: Bool = false
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
    
    var body: some View {
        ZStack {
            if !hasPermission {
                PermissionView {
                    requestPermission()
                }
            } else if let errorMessage = errorMessage {
                ErrorView(message: errorMessage) {
                    loadAlbums()
                }
            } else if isLoading {
                LoadingView()
            } else {
                VStack {
                    // 顶部导航栏
                    NavigationBar(
                        title: selectedAlbum?.title ?? "相册",
                        showAlbumList: $showAlbumList,
                        isMultiSelect: $isMultiSelect,
                        selectedCount: selectedAssets.count,
                        onDone: {}
                    )
                    
                    // 内容区域
                    if showAlbumList {
                        AlbumListView(
                            albums: albums,
                            selectedAlbum: $selectedAlbum,
                            onSelectAlbum: { album in
                                selectedAlbum = album
                                showAlbumList = false
                                loadAssets(in: album)
                            }
                        )
                    } else {
                        CMAssetGridView(
                            assets: assets,
                            selectedAssets: $selectedAssets,
                            isMultiSelect: isMultiSelect,
                            onAssetTap: { asset, rect in
                                previewStartFrame = rect
                                if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                                    previewIndex = index
                                }
                                showPreview = true
                            }
                        )
                    }
                }
            }
        }
        ZStack(alignment: .topLeading) {
            // 主内容
            VStack {
                if !hasPermission {
                    PermissionView {
                        requestPermission()
                    }
                } else if let errorMessage = errorMessage {
                    ErrorView(message: errorMessage) {
                        loadAlbums()
                    }
                } else if isLoading {
                    LoadingView()
                } else {
                    VStack {
                        // 顶部导航栏
                        NavigationBar(
                            title: selectedAlbum?.title ?? "相册",
                            showAlbumList: $showAlbumList,
                            isMultiSelect: $isMultiSelect,
                            selectedCount: selectedAssets.count,
                            onDone: {}
                        )
                        
                        // 内容区域
                        if showAlbumList {
                            AlbumListView(
                                albums: albums,
                                selectedAlbum: $selectedAlbum,
                                onSelectAlbum: { album in
                                    selectedAlbum = album
                                    showAlbumList = false
                                    loadAssets(in: album)
                                }
                            )
                        } else {
                            CMAssetGridView(
                                assets: assets,
                                selectedAssets: $selectedAssets,
                                isMultiSelect: isMultiSelect,
                                onAssetTap: { asset, rect in
                                    previewStartFrame = rect
                                    if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                                        previewIndex = index
                                    }
                                    showPreview = true
                                }
                            )
                        }
                    }
                }
            }
            
            // 预览和编辑视图
            if showPreview {
                HeroAnimationContainer(isVisible: $showPreview) {
                    CMAssetPreviewView(
                        assets: $assets,
                        initialIndex: previewIndex,
                        selectedAssets: $selectedAssets,
                        isMultiSelect: isMultiSelect,
                        onDismiss: { showPreview = false },
                        onEdit: { asset in
                            showPreview = false
                            currentEditAsset = asset
                            showEditView = true
                        }
                    )
                }
            }
            
            if showEditView, let asset = currentEditAsset {
                HeroAnimationContainer(isVisible: $showEditView) {
                    CMAssetDetailView(
                        asset: asset,
                        onDismiss: { showEditView = false },
                        onSave: { editedAsset in
                            showEditView = false
                            // 这里可以添加保存逻辑
                        }
                    )
                }
            }
        }
        .onAppear {
            requestPermission()
        }
    }
    
    /// 请求权限
    private func requestPermission() {
        Task {
            do {
                hasPermission = try await CMAssetManager.shared.requestPermission()
                if hasPermission {
                    loadAlbums()
                }
            } catch {
                errorMessage = "请求权限失败"
                isLoading = false
            }
        }
    }
    
    /// 加载相册列表
    private func loadAlbums() {
        isLoading = true
        Task {
            do {
                albums = try await CMAssetManager.shared.getAlbums()
                if let firstAlbum = albums.first {
                    selectedAlbum = firstAlbum
                    loadAssets(in: firstAlbum)
                }
                isLoading = false
            } catch {
                errorMessage = "加载相册失败"
                isLoading = false
            }
        }
    }
    
    /// 加载相册中的图片
    /// - Parameter album: 相册
    private func loadAssets(in album: CMAssetCollection) {
        isLoading = true
        Task {
            do {
                assets = try await CMAssetManager.shared.getAssets(in: album)
                isLoading = false
            } catch {
                errorMessage = "加载图片失败"
                isLoading = false
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
    
    var body: some View {
        HStack {
            Button(action: { showAlbumList.toggle() }) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                Image(systemName: "chevron.down")
                    .foregroundColor(.black)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(radius: 2)
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
        CMAssetPickerView(selectedAssets: .constant([]))
    }
}