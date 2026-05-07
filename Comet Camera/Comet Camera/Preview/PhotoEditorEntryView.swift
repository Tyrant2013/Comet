//
//  PhotoEditorEntryView.swift
//  Comet Camera
//

import SwiftUI
import UIKit
import Photos
import PhotoEditor
import CoreImage
import Asset

enum EditorMode {
    case adjust
    case filter
    case crop
    
    var title: String {
        switch self {
        case .adjust: return "调整"
        case .filter: return "滤镜"
        case .crop: return "剪裁"
        }
    }
}

struct PhotoEditorEntryView: View {
    let image: UIImage
    let source: ImageSource
    let asset: CMAsset?
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentMode: EditorMode = .adjust
    @State private var editedImage: UIImage
    @State private var showCropView = false
    @State private var saveSuccess = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 编辑参数
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var exposure: Double = 0
    @State private var warmth: Double = 0
    @State private var tint: Double = 0
    
    // 滤镜
    @State private var selectedFilter: CMPhotoEditorFilter? = nil
    
    init(image: UIImage, source: ImageSource = .camera, asset: CMAsset? = nil) {
        self.image = image
        self.source = source
        self.asset = asset
        _editedImage = State(initialValue: image)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text(currentMode.title)
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        saveEditedImage()
                    }) {
                        Text("完成")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // 图片显示区域
                GeometryReader { geometry in
                    Image(uiImage: editedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // 模式选择器
                HStack(spacing: 0) {
                    ForEach([EditorMode.adjust, EditorMode.filter], id: \.self) { mode in
                        Button(action: {
                            withAnimation {
                                currentMode = mode
                            }
                        }) {
                            Text(mode.title)
                                .font(.system(size: 14))
                                .foregroundColor(currentMode == mode ? .orange : .white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // 剪裁按钮
                    Button(action: {
                        showCropView = true
                    }) {
                        Text(EditorMode.crop.title)
                            .font(.system(size: 14))
                            .foregroundColor(currentMode == .crop ? .orange : .white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                }
                .background(Color.black.opacity(0.6))
                
                // 根据模式显示不同的控制面板
                Group {
                    switch currentMode {
                    case .adjust:
                        AdjustPanelView(
                            brightness: $brightness,
                            contrast: $contrast,
                            saturation: $saturation,
                            exposure: $exposure,
                            warmth: $warmth,
                            tint: $tint,
                            onApply: applyAdjustments
                        )
                    case .filter:
                        FilterPanelView(
                            originalImage: image,
                            selectedFilter: $selectedFilter,
                            onFilterSelected: applyFilter
                        )
                    case .crop:
                        EmptyView()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCropView) {
            CropEditorView(image: editedImage) { croppedImage in
                editedImage = croppedImage
                showCropView = false
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(saveSuccess ? "保存成功" : "保存失败"), message: Text(alertMessage))
        }
    }
    
    private func applyAdjustments() {
        guard let ciImage = CIImage(image: image) else { return }
        
        do {
            var context = CMPhotoEditContext(image: ciImage)
            
            let colorAdjustOp = CMColorAdjustOperation(
                configuration: .init(
                    brightness: brightness,
                    contrast: contrast,
                    saturation: saturation,
                    exposureEV: exposure,
                    warmth: warmth,
                    tint: tint
                )
            )
            
            let engine = CMPhotoEditorEngine()
            let result = try engine.run(operations: [colorAdjustOp], context: &context)
            
            // 将CIImage转换为UIImage
            let ciContext = CIContext()
            if let cgImage = ciContext.createCGImage(result, from: result.extent) {
                DispatchQueue.main.async {
                    self.editedImage = UIImage(cgImage: cgImage)
                }
            }
        } catch {
            print("应用调整失败: \(error)")
        }
    }
    
    private func applyFilter(_ filter: CMPhotoEditorFilter) {
        selectedFilter = filter
        
        guard let ciImage = CIImage(image: image) else { return }
        
        do {
            var context = CMPhotoEditContext(image: ciImage)
            
            let filterOp = CMFilterOperation(filter: filter)
            
            let engine = CMPhotoEditorEngine()
            let result = try engine.run(operations: [filterOp], context: &context)
            
            // 将CIImage转换为UIImage
            let ciContext = CIContext()
            if let cgImage = ciContext.createCGImage(result, from: result.extent) {
                DispatchQueue.main.async {
                    self.editedImage = UIImage(cgImage: cgImage)
                }
            }
        } catch {
            print("应用滤镜失败: \(error)")
        }
    }
    
    private func saveEditedImage() {
        saveToAppStorage()
    }
    
    private func saveToAppStorage() {
        Task {
            do {
                // 保存编辑元数据
                let editMetadata: [String: Any] = [
                    "brightness": brightness,
                    "contrast": contrast,
                    "saturation": saturation,
                    "exposure": exposure,
                    "warmth": warmth,
                    "tint": tint,
                    "hasFilter": selectedFilter != nil
                ]
                
                _ = try await PhotoStorageService.shared.savePhoto(
                    image: editedImage,
                    editMetadata: editMetadata
                )
                
                await MainActor.run {
                    alertMessage = "图片已保存到应用"
                    saveSuccess = true
                    showAlert = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "保存失败: \(error.localizedDescription)"
                    saveSuccess = false
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - 调整面板
struct AdjustPanelView: View {
    @Binding var brightness: Double
    @Binding var contrast: Double
    @Binding var saturation: Double
    @Binding var exposure: Double
    @Binding var warmth: Double
    @Binding var tint: Double
    
    let onApply: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ParameterSlider(
                    title: "亮度",
                    value: $brightness,
                    range: -1...1,
                    defaultValue: 0,
                    onEditingChanged: { _ in onApply() }
                )
                
                ParameterSlider(
                    title: "对比度",
                    value: $contrast,
                    range: 0...2,
                    defaultValue: 1,
                    onEditingChanged: { _ in onApply() }
                )
                
                ParameterSlider(
                    title: "饱和度",
                    value: $saturation,
                    range: 0...2,
                    defaultValue: 1,
                    onEditingChanged: { _ in onApply() }
                )
                
                ParameterSlider(
                    title: "曝光",
                    value: $exposure,
                    range: -1...1,
                    defaultValue: 0,
                    onEditingChanged: { _ in onApply() }
                )
                
                ParameterSlider(
                    title: "色温",
                    value: $warmth,
                    range: -1...1,
                    defaultValue: 0,
                    onEditingChanged: { _ in onApply() }
                )
                
                ParameterSlider(
                    title: "色调",
                    value: $tint,
                    range: -1...1,
                    defaultValue: 0,
                    onEditingChanged: { _ in onApply() }
                )
                
                // 重置按钮
                Button(action: resetAll) {
                    Text("重置所有")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.6))
    }
    
    private func resetAll() {
        brightness = 0
        contrast = 1
        saturation = 1
        exposure = 0
        warmth = 0
        tint = 0
        onApply()
    }
}

// MARK: - 参数滑块组件
struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Slider(
                value: $value,
                in: range,
                onEditingChanged: onEditingChanged ?? { _ in },
                minimumValueLabel: Text(String(format: "%.1f", range.lowerBound))
                    .font(.caption2)
                    .foregroundColor(.gray),
                maximumValueLabel: Text(String(format: "%.1f", range.upperBound))
                    .font(.caption2)
                    .foregroundColor(.gray),
                label: { Text(title) }
            )
            .accentColor(.orange)
        }
    }
}

// MARK: - 滤镜面板
struct FilterPanelView: View {
    let originalImage: UIImage
    @Binding var selectedFilter: CMPhotoEditorFilter?
    let onFilterSelected: (CMPhotoEditorFilter) -> Void
    
    @State private var filters: [CMPhotoEditorFilter] = []
    @State private var filterPreviews: [UIImage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterPreviewItem(
                        image: originalImage,
                        name: "原图",
                        isSelected: selectedFilter == nil
                    ) {
                        selectedFilter = nil
                    }
                    
                    ForEach(filters.indices, id: \.self) { index in
                        let filter = filters[index]
                        let previewImg = filterPreviews.count > index ? filterPreviews[index] : originalImage
                        
                        FilterPreviewItem(
                            image: previewImg,
                            name: "滤镜\(index + 1)",
                            isSelected: false
                        ) {
                            onFilterSelected(filter)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(Color.black.opacity(0.6))
        .onAppear {
            loadFilters()
        }
    }
    
    private func loadFilters() {
        filters = CMPhotoEditorFilter.allFilters()
        DispatchQueue.global(qos: .userInitiated).async {
            let previews = filters.map { filter in
                return filter.preview(on: originalImage) ?? originalImage
            }
            DispatchQueue.main.async {
                filterPreviews = previews
            }
        }
    }
}

// MARK: - 滤镜预览项
struct FilterPreviewItem: View {
    let image: UIImage
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
                
                Text(name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .orange : .white)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - 剪裁编辑器
struct CropEditorView: UIViewControllerRepresentable {
    let image: UIImage
    let onCropComplete: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CMCropViewController {
        let cropVC = CMCropViewController(image: image)
        cropVC.delegate = context.coordinator
        return cropVC
    }
    
    func updateUIViewController(_ uiViewController: CMCropViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCropComplete: onCropComplete)
    }
    
    class Coordinator: NSObject, CMCropViewControllerDelegate {
        let onCropComplete: (UIImage) -> Void
        
        init(onCropComplete: @escaping (UIImage) -> Void) {
            self.onCropComplete = onCropComplete
        }
        
        func cropViewController(_ cropViewController: CMCropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            onCropComplete(image)
            cropViewController.dismiss(animated: true)
        }
        
        func cropViewController(_ cropViewController: CMCropViewController, didFinishCancelled cancelled: Bool) {
            cropViewController.dismiss(animated: true)
        }
    }
}

// MARK: - Helper Extensions
extension CMPhotoEditorFilterType {
    var displayName: String {
        switch self {
        case .normal: return "原图"
        case .blackAndWhite: return "黑白"
        case .sepia: return "复古"
        case .vintage: return "怀旧"
        case .chrome: return "铬色"
        case .fade: return "褪色"
        case .instant: return "即时"
        case .process: return "处理"
        case .transfer: return "转换"
        case .curve: return "曲线"
        case .tonal: return "色调"
        case .mono: return "单色"
        }
    }
}

#Preview {
    PhotoEditorEntryView(image: UIImage(named: "PreviewImage")!)
}
