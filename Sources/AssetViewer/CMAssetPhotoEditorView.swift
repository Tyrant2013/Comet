import SwiftUI
import Combine
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotoEditor

public struct CMAssetPhotoEditorView: View {
    private let asset: CMAsset
    private let onSave: (CIImage) -> Void
    private let onCancel: () -> Void
    
    @StateObject private var viewModel: CMAssetPhotoEditorViewModel
    @State private var imageContentMode: CMPhotoEditorContentMode = .scaleAspectFit
    
    public init(
        asset: CMAsset,
        onSave: @escaping (CIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.asset = asset
        self.onSave = onSave
        self.onCancel = onCancel
        self._viewModel = StateObject(wrappedValue: CMAssetPhotoEditorViewModel(asset: asset))
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                imagePreview
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.5)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                controls
            }
            .navigationTitle("编辑图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if let editedImage = viewModel.editedImage {
                            onSave(editedImage)
                        }
                    }
                    .disabled(viewModel.editedImage == nil || viewModel.isProcessing)
                }
            }
            .onAppear {
                viewModel.loadImage()
            }
        }
    }
    
    @ViewBuilder
    private var imagePreview: some View {
        ZStack {
            Color.black
            
            if let ciImage = viewModel.editedImage ?? viewModel.sourceImage {
                CMPhotoEditorMetalView(image: ciImage, imageContentMode: imageContentMode)
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
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    @ViewBuilder
    private var controls: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionHeader("调色")
                
                HStack(spacing: 16) {
                    controlRow("亮度", value: $viewModel.brightness, range: -1...1)
                    controlRow("对比度", value: $viewModel.contrast, range: 0.5...2)
                }
                
                HStack(spacing: 16) {
                    controlRow("饱和度", value: $viewModel.saturation, range: 0...2)
                    controlRow("曝光", value: $viewModel.exposureEV, range: -2...2)
                }
                
                sectionHeader("滤镜")
                
                Picker("滤镜", selection: $viewModel.selectedFilter) {
                    ForEach(EditorFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                sectionHeader("裁剪")
                
                Toggle("启用裁剪", isOn: $viewModel.cropEnabled)
                    .padding(.horizontal, 16)
                
                if viewModel.cropEnabled {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            controlRow("缩放", value: $viewModel.cropZoom, range: 1...4)
                            controlRow("旋转", value: $viewModel.cropRotation, range: -180...180)
                        }
                        
                        Picker("比例", selection: $viewModel.cropAspect) {
                            ForEach(EditorAspect.allCases, id: \.self) { aspect in
                                Text(aspect.title).tag(aspect)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                    }
                }
                
                sectionHeader("文字")
                
                Toggle("添加文字", isOn: $viewModel.textEnabled)
                    .padding(.horizontal, 16)
                
                if viewModel.textEnabled {
                    VStack(spacing: 12) {
                        TextField("输入文字", text: $viewModel.overlayText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)
                        
                        HStack(spacing: 16) {
                            controlRow("X", value: $viewModel.textX, range: 0...0.95)
                            controlRow("Y", value: $viewModel.textY, range: 0...0.95)
                        }
                        
                        controlRow("大小", value: $viewModel.textSize, range: 12...64)
                    }
                }
                
                sectionHeader("打码")
                
                Toggle("启用打码", isOn: $viewModel.mosaicEnabled)
                    .padding(.horizontal, 16)
                
                if viewModel.mosaicEnabled {
                    VStack(spacing: 12) {
                        Toggle("自动识别敏感信息", isOn: $viewModel.autoMosaic)
                            .padding(.horizontal, 16)
                        
                        controlRow("打码强度", value: $viewModel.mosaicScale, range: 4...60)
                    }
                }
                
                HStack(spacing: 12) {
                    Button("重置") {
                        viewModel.reset()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .padding(.vertical, 16)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private func controlRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

public final class CMAssetPhotoEditorViewModel: ObservableObject {
    @Published public var sourceImage: CIImage?
    @Published public var editedImage: CIImage?
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    @Published public var isProcessing: Bool = false
    
    @Published public var brightness: Double = 0
    @Published public var contrast: Double = 1
    @Published public var saturation: Double = 1
    @Published public var exposureEV: Double = 0
    
    @Published public var selectedFilter: EditorFilter = .none
    
    @Published public var cropEnabled: Bool = false
    @Published public var cropZoom: Double = 1
    @Published public var cropRotation: Double = 0
    @Published public var cropAspect: EditorAspect = .square
    
    @Published public var textEnabled: Bool = false
    @Published public var overlayText: String = ""
    @Published public var textX: Double = 0.1
    @Published public var textY: Double = 0.1
    @Published public var textSize: Double = 28
    
    @Published public var mosaicEnabled: Bool = false
    @Published public var autoMosaic: Bool = true
    @Published public var mosaicScale: Double = 24
    
    private let asset: CMAsset
    private var cancellables = Set<AnyCancellable>()
    
    public init(asset: CMAsset) {
        self.asset = asset
        setupBindings()
    }
    
    private func setupBindings() {
        Publishers.CombineLatest4($brightness, $contrast, $saturation, $exposureEV)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)
        
        $selectedFilter
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4($cropEnabled, $cropZoom, $cropRotation, $cropAspect)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest4($textEnabled, $overlayText, $textX, $textY)
            .combineLatest($textSize)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest3($mosaicEnabled, $autoMosaic, $mosaicScale)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)
    }
    
    public func loadImage() {
        isLoading = true
        error = nil
        
        asset.requestImage { [weak self] image in
            guard let self = self else { return }
            
            if let image = image {
                if let ciImage = self.ciImage(from: image) {
                    self.sourceImage = ciImage
                    self.editedImage = ciImage
                } else {
                    self.error = NSError(domain: "CMAssetPhotoEditor", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法转换图片"])
                }
            } else {
                self.error = NSError(domain: "CMAssetPhotoEditor", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法加载图片"])
            }
            
            self.isLoading = false
        }
    }
    
    private func applyEdits() {
        guard let sourceImage = sourceImage else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var operations: [CMPhotoEditOperation] = []
            
            operations.append(CMColorAdjustOperation(configuration: .init(
                brightness: self.brightness,
                contrast: self.contrast,
                saturation: self.saturation,
                exposureEV: self.exposureEV
            )))
            
            operations.append(CMFilterOperation(filter: self.selectedFilter.filter))
            
            if self.cropEnabled {
                let state = CMCropState(
                    imageSize: sourceImage.extent.size,
                    zoomScale: self.cropZoom,
                    panOffset: CGPoint(x: 0, y: 0),
                    rotationDegrees: self.cropRotation,
                    outputAspectRatio: self.cropAspect.ratio
                )
                operations.append(CMCropOperation(state: state))
            }
            
            if self.textEnabled, !self.overlayText.isEmpty {
                let textOp = CMTextOverlayOperation(configuration: .init(
                    text: self.overlayText,
                    normalizedOrigin: CGPoint(x: self.textX, y: self.textY),
                    fontSize: self.textSize,
                    color: UIColor.white.cgColor
                ))
                operations.append(textOp)
            }
            
            if self.mosaicEnabled {
                let extent = sourceImage.extent
                let manualRect = CGRect(
                    x: extent.minX + extent.width * 0.2,
                    y: extent.minY + extent.height * 0.2,
                    width: extent.width * 0.4,
                    height: extent.height * 0.2
                )
                
                let config = CMMosaicOperation.Configuration(
                    manualRegions: [manualRect],
                    autoDetectSensitiveData: self.autoMosaic,
                    mosaicScale: self.mosaicScale
                )
                
                let detector: CMSensitiveDataDetecting? = {
                    if self.autoMosaic {
                        if #available(iOS 13.0, *) {
                            return CMVisionSensitiveDataDetector()
                        }
                    }
                    return nil
                }()
                
                operations.append(CMMosaicOperation(configuration: config, detector: detector))
            }
            
            do {
                let output = try PhotoEditor.CMPhotoEditor.edit(sourceImage, operations: operations)
                DispatchQueue.main.async {
                    self.editedImage = output
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isProcessing = false
                }
            }
        }
    }
    
    public func reset() {
        brightness = 0
        contrast = 1
        saturation = 1
        exposureEV = 0
        selectedFilter = .none
        
        cropEnabled = false
        cropZoom = 1
        cropRotation = 0
        cropAspect = .square
        
        textEnabled = false
        overlayText = ""
        textX = 0.1
        textY = 0.1
        textSize = 28
        
        mosaicEnabled = false
        autoMosaic = true
        mosaicScale = 24
        
        editedImage = sourceImage
    }
    
    private func ciImage(from image: UIImage) -> CIImage? {
        if let ci = image.ciImage {
            return ci
        }
        if let cg = image.cgImage {
            return CIImage(cgImage: cg)
        }
        return nil
    }
}

public enum EditorFilter: CaseIterable {
    case none
    case noir
    case chrome
    case mono
    case instant
    
    var title: String {
        switch self {
        case .none: return "无"
        case .noir: return "Noir"
        case .chrome: return "Chrome"
        case .mono: return "Mono"
        case .instant: return "Instant"
        }
    }
    
    var filter: CMPhotoEditorFilter {
        switch self {
        case .none: return .none
        case .noir: return .noir
        case .chrome: return .chrome
        case .mono: return .mono
        case .instant: return .instant
        }
    }
}

public enum EditorAspect: CaseIterable {
    case square
    case ratio4x3
    case ratio16x9
    
    var title: String {
        switch self {
        case .square: return "1:1"
        case .ratio4x3: return "4:3"
        case .ratio16x9: return "16:9"
        }
    }
    
    var ratio: CGFloat {
        switch self {
        case .square: return 1
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        }
    }
}
