//
//  CMAssetPreviewView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine
import Photos
import CoreImage
import PhotoEditor

public struct CMAssetPreviewView: View {
    @ObservedObject private var viewModel: CMAssetPreviewViewModel
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isNavigationBarVisible: Bool = true
    
    private let onDismiss: (Int) -> Void
    
    public init(
        assets: [CMAsset],
        initialIndex: Int = 0,
        onDismiss: @escaping (Int) -> Void = { _ in }
    ) {
        self.viewModel = CMAssetPreviewViewModel(assets: assets, initialIndex: initialIndex)
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isNavigationBarVisible {
                    navigationBar
                }
                
                Spacer()
                
                contentView
                
                Spacer()
            }
            
            editStateOverlay
        }
        .statusBar(hidden: !isNavigationBarVisible)
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isNavigationBarVisible.toggle()
            }
        }
        .sheet(isPresented: $viewModel.isEditing) {
            if let asset = viewModel.getCurrentAsset(), asset.assetType == .image {
                CMAssetPhotoEditorView(
                    asset: asset,
                    onSave: { editedImage in
                        viewModel.saveEditedImage(editedImage)
                    },
                    onCancel: {
                        viewModel.cancelEditing()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            Button(action: handleDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("\(viewModel.currentIndex + 1) / \(viewModel.assets.count)")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if let asset = viewModel.getCurrentAsset(), asset.assetType == .image {
                Button(action: {
                    viewModel.startEditing()
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
    
    @ViewBuilder
    private var contentView: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                CMAssetPreviewImageView(
                    asset: asset,
                    imageCache: .shared
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
    
    private func handleDismiss() {
        onDismiss(viewModel.currentIndex)
    }
    
    @ViewBuilder
    private var editStateOverlay: some View {
        switch viewModel.editState {
        case .idle:
            EmptyView()
        case .editing:
            EmptyView()
        case .saving:
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("正在保存...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        case .saved:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("保存成功")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .transition(.opacity)
        case .error(let error):
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("保存失败")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(error.localizedDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .transition(.opacity)
        }
    }
}

public final class CMAssetPreviewViewModel: ObservableObject {
    @Published public var currentIndex: Int
    @Published public var assets: [CMAsset]
    @Published public var isEditing: Bool = false
    @Published public var editedImage: CIImage?
    @Published public var editState: EditState = .idle
    
    public enum EditState {
        case idle
        case editing
        case saving
        case saved
        case error(Error)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public init(assets: [CMAsset], initialIndex: Int = 0) {
        self.assets = assets
        self.currentIndex = initialIndex
        
        setupBindings()
    }
    
    private func setupBindings() {
        $currentIndex
            .sink { [weak self] index in
                self?.handleIndexChange(index)
            }
            .store(in: &cancellables)
    }
    
    private func handleIndexChange(_ index: Int) {
        guard index >= 0 && index < assets.count else { return }
    }
    
    public func updateAssets(_ newAssets: [CMAsset]) {
        assets = newAssets
        currentIndex = min(currentIndex, max(0, newAssets.count - 1))
    }
    
    public func startEditing() {
        isEditing = true
        editState = .editing
    }
    
    public func cancelEditing() {
        isEditing = false
        editedImage = nil
        editState = .idle
    }
    
    public func saveEditedImage(_ image: CIImage) {
        editedImage = image
        editState = .saving
        
        CMPhotoEditorSave.saveToPhotoLibrary(image) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success:
                    self.editState = .saved
                    self.isEditing = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.editState = .idle
                    }
                case .failure(let error):
                    self.editState = .error(error)
                }
            }
        }
    }
    
    public func getCurrentAsset() -> CMAsset? {
        guard currentIndex >= 0 && currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }
}

public struct CMAssetPreviewImageView: View {
    @ObservedObject private var viewModel: CMAssetPreviewImageViewModel
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let asset: CMAsset
    private let imageCache: CMImageCache
    
    public init(asset: CMAsset, imageCache: CMImageCache = .shared) {
        self.asset = asset
        self.imageCache = imageCache
        self.viewModel = CMAssetPreviewImageViewModel(asset: asset, imageCache: imageCache)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = viewModel.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        currentScale = max(1.0, min(currentScale * delta, 5.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if currentScale < 1.0 {
                                            withAnimation(.easeOut) {
                                                currentScale = 1.0
                                                currentOffset = .zero
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        currentOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        if currentScale == 1.0 {
                                            withAnimation(.easeOut) {
                                                currentOffset = .zero
                                            }
                                        }
                                        lastOffset = currentOffset
                                    }
                            )
                        )
                } else if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("加载失败")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Button(action: {
                            viewModel.loadImage()
                        }) {
                            Text("重试")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewModel.loadImage()
            }
        }
    }
}

public final class CMAssetPreviewImageViewModel: ObservableObject {
    @Published public var image: UIImage?
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    
    private let asset: CMAsset
    private let imageCache: CMImageCache
    private var cancellables = Set<AnyCancellable>()
    
    public init(asset: CMAsset, imageCache: CMImageCache = .shared) {
        self.asset = asset
        self.imageCache = imageCache
    }
    
    public func loadImage() {
        isLoading = true
        error = nil
        
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
        
        imageCache.loadImage(for: asset.asset, size: targetSize, mode: .aspectFit)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .idle:
                    break
                case .loading:
                    self.isLoading = true
                case .loaded(let image):
                    self.image = image
                    self.isLoading = false
                    self.error = nil
                case .failed(let error):
                    self.image = nil
                    self.isLoading = false
                    self.error = error
                }
            }
            .store(in: &cancellables)
    }
}

public extension CMAssetPreviewView {
    func updateAssets(_ assets: [CMAsset]) {
        viewModel.updateAssets(assets)
    }
    
    func getCurrentIndex() -> Int {
        viewModel.currentIndex
    }
}

struct CMAssetPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetPreviewView(
            assets: [],
            initialIndex: 0
        )
    }
}
