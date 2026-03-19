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
    @State private var watermarkSelectionDragStart: CGPoint?
    @State private var mosaicSelectionDragStart: CGPoint?
    @State private var mosaicDraftNormalizedRect: CGRect?
    
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
        GeometryReader { proxy in
            ZStack {
                Color.black
                
                if let ciImage = viewModel.editedImage ?? viewModel.sourceImage {
                    CMPhotoEditorMetalView(image: ciImage, imageContentMode: imageContentMode)

                    if viewModel.watermarkRemovalEnabled,
                       viewModel.watermarkManualSelectionEnabled {
                        let imageRect = displayedImageRect(
                            in: proxy.size,
                            imageSize: ciImage.extent.size,
                            contentMode: imageContentMode
                        )

                        if imageRect.width > 0, imageRect.height > 0 {
                            let selectionRect = selectionRectInView(imageRect: imageRect)
                            watermarkSelectionOverlay(selectionRect: selectionRect)
                                .allowsHitTesting(false)
                        }
                    }

                    if viewModel.mosaicEnabled,
                       viewModel.mosaicManualEnabled {
                        let imageRect = displayedImageRect(
                            in: proxy.size,
                            imageSize: ciImage.extent.size,
                            contentMode: imageContentMode
                        )

                        if imageRect.width > 0, imageRect.height > 0 {
                            mosaicSelectionOverlay(imageRect: imageRect)
                                .allowsHitTesting(false)
                        }
                    }
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleImageSelectionDrag(value, containerSize: proxy.size)
                    }
                    .onEnded { value in
                        handleImageSelectionDrag(value, containerSize: proxy.size, isEnding: true)
                    }
            )
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
                        Toggle("手动打码", isOn: $viewModel.mosaicManualEnabled)
                            .padding(.horizontal, 16)

                        if viewModel.mosaicManualEnabled {
                            HStack {
                                Text("在预览图上拖动可连续框选打码区域")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            HStack(spacing: 12) {
                                Button("撤销上一个") {
                                    viewModel.removeLastMosaicRegion()
                                }
                                .disabled(viewModel.mosaicManualRegionsNormalized.isEmpty)

                                Button("清空区域") {
                                    viewModel.clearMosaicRegions()
                                }
                                .disabled(viewModel.mosaicManualRegionsNormalized.isEmpty)
                            }
                            .padding(.horizontal, 16)
                        }

                        Toggle("自动识别敏感信息", isOn: $viewModel.autoMosaic)
                            .padding(.horizontal, 16)
                        
                        controlRow("打码强度", value: $viewModel.mosaicScale, range: 4...60)
                    }
                }

                sectionHeader("背景")

                Toggle("去除背景", isOn: $viewModel.backgroundRemovalEnabled)
                    .padding(.horizontal, 16)

                if viewModel.backgroundRemovalEnabled {
                    controlRow("边缘柔化", value: $viewModel.backgroundFeather, range: 0...8)
                }

                sectionHeader("去水印")

                Toggle("去除水印", isOn: $viewModel.watermarkRemovalEnabled)
                    .padding(.horizontal, 16)

                if viewModel.watermarkRemovalEnabled {
                    VStack(spacing: 12) {
                        Toggle("手动框选", isOn: $viewModel.watermarkManualSelectionEnabled)
                            .padding(.horizontal, 16)

                        if viewModel.watermarkManualSelectionEnabled {
                            HStack {
                                Text("在预览图上拖动即可框选去水印区域")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)

                            Button("重置选区") {
                                viewModel.resetWatermarkSelectionRect()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(8)
                        } else {
                            Picker("水印位置", selection: $viewModel.watermarkRemovalCorner) {
                                ForEach(EditorCorner.allCases, id: \.self) { corner in
                                    Text(corner.title).tag(corner)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)

                            HStack(spacing: 16) {
                                controlRow("宽度占比", value: $viewModel.watermarkRemovalWidth, range: 0.08...0.6)
                                controlRow("高度占比", value: $viewModel.watermarkRemovalHeight, range: 0.05...0.35)
                            }
                        }

                        HStack(spacing: 16) {
                            controlRow("模糊强度", value: $viewModel.watermarkRemovalBlur, range: 0...30)
                            controlRow("边缘过渡", value: $viewModel.watermarkRemovalFeather, range: 0...12)
                        }
                    }
                }

                sectionHeader("添加水印")

                Toggle("添加水印", isOn: $viewModel.watermarkEnabled)
                    .padding(.horizontal, 16)

                if viewModel.watermarkEnabled {
                    VStack(spacing: 12) {
                        TextField("输入水印文字", text: $viewModel.watermarkText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)

                        Picker("水印位置", selection: $viewModel.watermarkCorner) {
                            ForEach(EditorCorner.allCases, id: \.self) { corner in
                                Text(corner.title).tag(corner)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        HStack(spacing: 16) {
                            controlRow("透明度", value: $viewModel.watermarkOpacity, range: 0.05...1)
                            controlRow("字号", value: $viewModel.watermarkSize, range: 12...72)
                        }

                        controlRow("旋转角度", value: $viewModel.watermarkRotation, range: -90...90)
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

    @ViewBuilder
    private func watermarkSelectionOverlay(selectionRect: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
            Rectangle()
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .background(Color.yellow.opacity(0.18))
                .frame(width: selectionRect.width, height: selectionRect.height)
                .position(x: selectionRect.midX, y: selectionRect.midY)
        }
    }

    private func handleWatermarkSelectionDrag(_ value: DragGesture.Value, containerSize: CGSize, isEnding: Bool = false) {
        guard viewModel.watermarkRemovalEnabled,
              viewModel.watermarkManualSelectionEnabled,
              let ciImage = viewModel.editedImage ?? viewModel.sourceImage else {
            if isEnding { watermarkSelectionDragStart = nil }
            return
        }

        let imageRect = displayedImageRect(in: containerSize, imageSize: ciImage.extent.size, contentMode: imageContentMode)
        guard imageRect.width > 0, imageRect.height > 0 else {
            if isEnding { watermarkSelectionDragStart = nil }
            return
        }

        if watermarkSelectionDragStart == nil {
            guard imageRect.contains(value.startLocation) else { return }
            watermarkSelectionDragStart = clamp(value.startLocation, to: imageRect)
        }

        guard let start = watermarkSelectionDragStart else { return }
        let current = clamp(value.location, to: imageRect)
        let rawRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        let minSize: CGFloat = 16
        if rawRect.width >= minSize, rawRect.height >= minSize {
            let normalized = CGRect(
                x: (rawRect.minX - imageRect.minX) / imageRect.width,
                y: (rawRect.minY - imageRect.minY) / imageRect.height,
                width: rawRect.width / imageRect.width,
                height: rawRect.height / imageRect.height
            )
            viewModel.watermarkSelectionNormalizedRect = viewModel.sanitizedNormalizedRect(normalized)
        }

        if isEnding {
            watermarkSelectionDragStart = nil
        }
    }

    private func handleImageSelectionDrag(_ value: DragGesture.Value, containerSize: CGSize, isEnding: Bool = false) {
        if viewModel.mosaicEnabled, viewModel.mosaicManualEnabled {
            handleMosaicSelectionDrag(value, containerSize: containerSize, isEnding: isEnding)
            return
        }
        handleWatermarkSelectionDrag(value, containerSize: containerSize, isEnding: isEnding)
    }

    private func handleMosaicSelectionDrag(_ value: DragGesture.Value, containerSize: CGSize, isEnding: Bool = false) {
        guard viewModel.mosaicEnabled,
              viewModel.mosaicManualEnabled,
              let ciImage = viewModel.editedImage ?? viewModel.sourceImage else {
            if isEnding {
                mosaicSelectionDragStart = nil
                mosaicDraftNormalizedRect = nil
            }
            return
        }

        let imageRect = displayedImageRect(in: containerSize, imageSize: ciImage.extent.size, contentMode: imageContentMode)
        guard imageRect.width > 0, imageRect.height > 0 else {
            if isEnding {
                mosaicSelectionDragStart = nil
                mosaicDraftNormalizedRect = nil
            }
            return
        }

        if mosaicSelectionDragStart == nil {
            guard imageRect.contains(value.startLocation) else { return }
            mosaicSelectionDragStart = clamp(value.startLocation, to: imageRect)
        }

        guard let start = mosaicSelectionDragStart else { return }
        let current = clamp(value.location, to: imageRect)
        let rawRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        let minSize: CGFloat = 16
        if rawRect.width >= minSize, rawRect.height >= minSize {
            let normalized = CGRect(
                x: (rawRect.minX - imageRect.minX) / imageRect.width,
                y: (rawRect.minY - imageRect.minY) / imageRect.height,
                width: rawRect.width / imageRect.width,
                height: rawRect.height / imageRect.height
            )
            mosaicDraftNormalizedRect = viewModel.sanitizedNormalizedRect(normalized)
        } else {
            mosaicDraftNormalizedRect = nil
        }

        if isEnding {
            if let draft = mosaicDraftNormalizedRect {
                viewModel.addMosaicRegion(draft)
            }
            mosaicSelectionDragStart = nil
            mosaicDraftNormalizedRect = nil
        }
    }

    private func selectionRectInView(imageRect: CGRect) -> CGRect {
        let normalized = viewModel.sanitizedNormalizedRect(viewModel.watermarkSelectionNormalizedRect)
        return CGRect(
            x: imageRect.minX + normalized.minX * imageRect.width,
            y: imageRect.minY + normalized.minY * imageRect.height,
            width: normalized.width * imageRect.width,
            height: normalized.height * imageRect.height
        )
    }

    @ViewBuilder
    private func mosaicSelectionOverlay(imageRect: CGRect) -> some View {
        let storedRects = viewModel.mosaicManualRegionsNormalized.map { region in
            CGRect(
                x: imageRect.minX + region.minX * imageRect.width,
                y: imageRect.minY + region.minY * imageRect.height,
                width: region.width * imageRect.width,
                height: region.height * imageRect.height
            )
        }

        let draftRect: CGRect? = {
            guard let draft = mosaicDraftNormalizedRect else { return nil }
            return CGRect(
                x: imageRect.minX + draft.minX * imageRect.width,
                y: imageRect.minY + draft.minY * imageRect.height,
                width: draft.width * imageRect.width,
                height: draft.height * imageRect.height
            )
        }()

        ZStack(alignment: .topLeading) {
            ForEach(Array(storedRects.enumerated()), id: \.offset) { _, rect in
                Rectangle()
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.red.opacity(0.16))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            if let draftRect {
                Rectangle()
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(Color.orange.opacity(0.2))
                    .frame(width: draftRect.width, height: draftRect.height)
                    .position(x: draftRect.midX, y: draftRect.midY)
            }
        }
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func displayedImageRect(in containerSize: CGSize, imageSize: CGSize, contentMode: CMPhotoEditorContentMode) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        switch contentMode {
        case .scaleAspectFit:
            if imageAspect > containerAspect {
                let width = containerSize.width
                let height = width / imageAspect
                return CGRect(x: 0, y: (containerSize.height - height) * 0.5, width: width, height: height)
            } else {
                let height = containerSize.height
                let width = height * imageAspect
                return CGRect(x: (containerSize.width - width) * 0.5, y: 0, width: width, height: height)
            }
        case .scaleAspectFill:
            if imageAspect > containerAspect {
                let height = containerSize.height
                let width = height * imageAspect
                return CGRect(x: (containerSize.width - width) * 0.5, y: 0, width: width, height: height)
            } else {
                let width = containerSize.width
                let height = width / imageAspect
                return CGRect(x: 0, y: (containerSize.height - height) * 0.5, width: width, height: height)
            }
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
    @Published public var mosaicManualEnabled: Bool = true
    @Published public var mosaicManualRegionsNormalized: [CGRect] = []
    @Published public var autoMosaic: Bool = true
    @Published public var mosaicScale: Double = 24

    @Published public var backgroundRemovalEnabled: Bool = false
    @Published public var backgroundFeather: Double = 1.5

    @Published public var watermarkRemovalEnabled: Bool = false
    @Published public var watermarkManualSelectionEnabled: Bool = true
    @Published public var watermarkRemovalCorner: EditorCorner = .topRight
    @Published public var watermarkRemovalWidth: Double = 0.28
    @Published public var watermarkRemovalHeight: Double = 0.14
    @Published public var watermarkRemovalBlur: Double = 16
    @Published public var watermarkRemovalFeather: Double = 4
    @Published public var watermarkSelectionNormalizedRect: CGRect = CGRect(x: 0.68, y: 0.04, width: 0.28, height: 0.14)

    @Published public var watermarkEnabled: Bool = false
    @Published public var watermarkText: String = ""
    @Published public var watermarkOpacity: Double = 0.35
    @Published public var watermarkSize: Double = 26
    @Published public var watermarkRotation: Double = -18
    @Published public var watermarkCorner: EditorCorner = .bottomRight
    
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
        
        let mosaicTriggers: [AnyPublisher<Void, Never>] = [
            $mosaicEnabled.map { _ in () }.eraseToAnyPublisher(),
            $mosaicManualEnabled.map { _ in () }.eraseToAnyPublisher(),
            $mosaicManualRegionsNormalized.map { _ in () }.eraseToAnyPublisher(),
            $autoMosaic.map { _ in () }.eraseToAnyPublisher(),
            $mosaicScale.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(mosaicTriggers)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($backgroundRemovalEnabled, $backgroundFeather)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)

        let watermarkRemovalTriggers: [AnyPublisher<Void, Never>] = [
            $watermarkRemovalEnabled.map { _ in () }.eraseToAnyPublisher(),
            $watermarkManualSelectionEnabled.map { _ in () }.eraseToAnyPublisher(),
            $watermarkRemovalCorner.map { _ in () }.eraseToAnyPublisher(),
            $watermarkRemovalWidth.map { _ in () }.eraseToAnyPublisher(),
            $watermarkRemovalHeight.map { _ in () }.eraseToAnyPublisher(),
            $watermarkRemovalBlur.map { _ in () }.eraseToAnyPublisher(),
            $watermarkRemovalFeather.map { _ in () }.eraseToAnyPublisher(),
            $watermarkSelectionNormalizedRect.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(watermarkRemovalTriggers)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyEdits()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4($watermarkEnabled, $watermarkText, $watermarkOpacity, $watermarkSize)
            .combineLatest($watermarkRotation, $watermarkCorner)
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
                let manualRegions = self.mosaicManualEnabled
                    ? self.mosaicRectsFromManualSelection(in: sourceImage.extent)
                    : []
                
                let config = CMMosaicOperation.Configuration(
                    manualRegions: manualRegions,
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

            if self.backgroundRemovalEnabled {
                operations.append(CMBackgroundRemovalOperation(configuration: .init(
                    edgeFeatherRadius: self.backgroundFeather
                )))
            }

            if self.watermarkRemovalEnabled {
                let removeRect = self.watermarkManualSelectionEnabled
                    ? self.watermarkRectFromManualSelection(in: sourceImage.extent)
                    : self.watermarkRect(in: sourceImage.extent)
                operations.append(CMWatermarkRemovalOperation(configuration: .init(
                    regions: [removeRect],
                    blurRadius: self.watermarkRemovalBlur,
                    featherRadius: self.watermarkRemovalFeather
                )))
            }

            if self.watermarkEnabled, !self.watermarkText.isEmpty {
                operations.append(CMWatermarkOverlayOperation(configuration: .init(
                    text: self.watermarkText,
                    normalizedOrigin: self.watermarkOrigin(for: self.watermarkCorner),
                    fontSize: self.watermarkSize,
                    color: UIColor.white.cgColor,
                    opacity: self.watermarkOpacity,
                    rotationDegrees: self.watermarkRotation
                )))
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
        mosaicManualEnabled = true
        mosaicManualRegionsNormalized = []
        autoMosaic = true
        mosaicScale = 24

        backgroundRemovalEnabled = false
        backgroundFeather = 1.5

        watermarkRemovalEnabled = false
        watermarkManualSelectionEnabled = true
        watermarkRemovalCorner = .topRight
        watermarkRemovalWidth = 0.28
        watermarkRemovalHeight = 0.14
        watermarkRemovalBlur = 16
        watermarkRemovalFeather = 4
        watermarkSelectionNormalizedRect = CGRect(x: 0.68, y: 0.04, width: 0.28, height: 0.14)

        watermarkEnabled = false
        watermarkText = ""
        watermarkOpacity = 0.35
        watermarkSize = 26
        watermarkRotation = -18
        watermarkCorner = .bottomRight
        
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

    private func watermarkRect(in extent: CGRect) -> CGRect {
        let widthRatio = max(0.05, min(0.9, watermarkRemovalWidth))
        let heightRatio = max(0.05, min(0.9, watermarkRemovalHeight))
        let width = extent.width * widthRatio
        let height = extent.height * heightRatio
        let inset = min(extent.width, extent.height) * 0.02

        let origin: CGPoint
        switch watermarkRemovalCorner {
        case .topLeft:
            origin = CGPoint(x: extent.minX + inset, y: extent.maxY - inset - height)
        case .topRight:
            origin = CGPoint(x: extent.maxX - inset - width, y: extent.maxY - inset - height)
        case .bottomLeft:
            origin = CGPoint(x: extent.minX + inset, y: extent.minY + inset)
        case .bottomRight:
            origin = CGPoint(x: extent.maxX - inset - width, y: extent.minY + inset)
        }

        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func watermarkRectFromManualSelection(in extent: CGRect) -> CGRect {
        let normalized = sanitizedNormalizedRect(watermarkSelectionNormalizedRect)
        let width = extent.width * normalized.width
        let height = extent.height * normalized.height
        let x = extent.minX + extent.width * normalized.minX
        let y = extent.maxY - extent.height * normalized.minY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func sanitizedNormalizedRect(_ rect: CGRect) -> CGRect {
        let minWidth: CGFloat = 0.03
        let minHeight: CGFloat = 0.03
        let width = max(minWidth, min(1, rect.width))
        let height = max(minHeight, min(1, rect.height))
        let x = max(0, min(1 - width, rect.minX))
        let y = max(0, min(1 - height, rect.minY))
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func resetWatermarkSelectionRect() {
        watermarkSelectionNormalizedRect = CGRect(x: 0.68, y: 0.04, width: 0.28, height: 0.14)
    }

    func addMosaicRegion(_ normalizedRect: CGRect) {
        mosaicManualRegionsNormalized.append(sanitizedNormalizedRect(normalizedRect))
    }

    func removeLastMosaicRegion() {
        guard !mosaicManualRegionsNormalized.isEmpty else { return }
        mosaicManualRegionsNormalized.removeLast()
    }

    func clearMosaicRegions() {
        mosaicManualRegionsNormalized.removeAll()
    }

    private func mosaicRectsFromManualSelection(in extent: CGRect) -> [CGRect] {
        mosaicManualRegionsNormalized.map { normalized in
            let safe = sanitizedNormalizedRect(normalized)
            let width = extent.width * safe.width
            let height = extent.height * safe.height
            let x = extent.minX + extent.width * safe.minX
            let y = extent.maxY - extent.height * safe.minY - height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    private func watermarkOrigin(for corner: EditorCorner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: 0.04, y: 0.88)
        case .topRight:
            return CGPoint(x: 0.68, y: 0.88)
        case .bottomLeft:
            return CGPoint(x: 0.04, y: 0.05)
        case .bottomRight:
            return CGPoint(x: 0.68, y: 0.05)
        }
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

public enum EditorCorner: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var title: String {
        switch self {
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        }
    }
}
