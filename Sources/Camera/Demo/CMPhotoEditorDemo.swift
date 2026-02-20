import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import PhotoEditor

public struct CMPhotoEditorDemo: View {
    @State private var sourceImage: UIImage = Self.makeSampleImage()
    @State private var previewImage: UIImage = Self.makeSampleImage()
    @State private var errorMessage: String?
    @State private var showPicker = false

    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var exposureEV: Double = 0

    @State private var selectedFilter: DemoFilter = .none

    @State private var cropEnabled: Bool = false
    @State private var cropZoom: CGFloat = 1
    @State private var cropPanX: CGFloat = 0
    @State private var cropPanY: CGFloat = 0
    @State private var cropRotation: CGFloat = 0
    @State private var cropAspect: DemoAspect = .square

    @State private var overlayText: String = "CONFIDENTIAL"
    @State private var textX: CGFloat = 0.1
    @State private var textY: CGFloat = 0.1
    @State private var textSize: CGFloat = 28
    @State private var textEnabled: Bool = false

    @State private var mosaicEnabled: Bool = false
    @State private var autoMosaic: Bool = true
    @State private var mosaicScale: Double = 24
    @State private var mosaicX: CGFloat = 0.2
    @State private var mosaicY: CGFloat = 0.2
    @State private var mosaicWidth: CGFloat = 0.4
    @State private var mosaicHeight: CGFloat = 0.2

    @State private var saveMessage: String?
    @State private var isSaving: Bool = false

    private let renderContext = CIContext(options: nil)

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                imagePreview
                controls
            }
            .padding(12)
            .navigationTitle("PhotoEditor Demo")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("示例图") {
                        sourceImage = Self.makeSampleImage()
                        applyAllEdits()
                    }
                    Button("相册") { showPicker = true }
                }
            }
            .sheet(isPresented: $showPicker) {
                DemoImagePicker { image in
                    guard let image else { return }
                    sourceImage = image
                    applyAllEdits()
                }
            }
            .onAppear {
                applyAllEdits()
            }
            .onChange(of: sourceImage) { _ in
                applyAllEdits()
            }
        }
    }

    private var imagePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(Color.black.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if let saveMessage {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 14) {
                sectionHeader("调色")
                sliderRow("Brightness", value: $brightness, range: -1...1)
                sliderRow("Contrast", value: $contrast, range: 0.5...2)
                sliderRow("Saturation", value: $saturation, range: 0...2)
                sliderRow("Exposure", value: $exposureEV, range: -2...2)

                sectionHeader("滤镜")
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(DemoFilter.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                sectionHeader("裁剪")
                Toggle("启用裁剪", isOn: $cropEnabled)
                sliderRow("Zoom", value: $cropZoom, range: 1...4)
                sliderRow("Move X", value: $cropPanX, range: -0.5...0.5)
                sliderRow("Move Y", value: $cropPanY, range: -0.5...0.5)
                sliderRow("Rotate", value: $cropRotation, range: -180...180)
                Picker("Aspect", selection: $cropAspect) {
                    ForEach(DemoAspect.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                sectionHeader("文字")
                Toggle("启用文字", isOn: $textEnabled)
                TextField("输入文本", text: $overlayText)
                    .textFieldStyle(.roundedBorder)
                sliderRow("Text X", value: $textX, range: 0...0.95)
                sliderRow("Text Y", value: $textY, range: 0...0.95)
                sliderRow("Text Size", value: $textSize, range: 12...64)

                sectionHeader("打码")
                Toggle("启用打码", isOn: $mosaicEnabled)
                Toggle("自动识别敏感信息", isOn: $autoMosaic)
                sliderRow("Mosaic Scale", value: $mosaicScale, range: 4...60)
                sliderRow("Rect X", value: $mosaicX, range: 0...0.95)
                sliderRow("Rect Y", value: $mosaicY, range: 0...0.95)
                sliderRow("Rect W", value: $mosaicWidth, range: 0.05...1)
                sliderRow("Rect H", value: $mosaicHeight, range: 0.05...1)

                HStack {
                    Button("应用编辑") { applyAllEdits() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    Button("复原图片") { resetAll() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    Button(isSaving ? "保存中..." : "保存到相册") { saveToPhotoLibrary() }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isSaving)
                }
            }
            .onChange(of: brightness) { _ in applyAllEdits() }
            .onChange(of: contrast) { _ in applyAllEdits() }
            .onChange(of: saturation) { _ in applyAllEdits() }
            .onChange(of: exposureEV) { _ in applyAllEdits() }
            .onChange(of: selectedFilter) { _ in applyAllEdits() }
            .onChange(of: cropEnabled) { _ in applyAllEdits() }
            .onChange(of: cropZoom) { _ in applyAllEdits() }
            .onChange(of: cropPanX) { _ in applyAllEdits() }
            .onChange(of: cropPanY) { _ in applyAllEdits() }
            .onChange(of: cropRotation) { _ in applyAllEdits() }
            .onChange(of: cropAspect) { _ in applyAllEdits() }
            .onChange(of: textEnabled) { _ in applyAllEdits() }
            .onChange(of: overlayText) { _ in applyAllEdits() }
            .onChange(of: textX) { _ in applyAllEdits() }
            .onChange(of: textY) { _ in applyAllEdits() }
            .onChange(of: textSize) { _ in applyAllEdits() }
            .onChange(of: mosaicEnabled) { _ in applyAllEdits() }
            .onChange(of: autoMosaic) { _ in applyAllEdits() }
            .onChange(of: mosaicScale) { _ in applyAllEdits() }
            .onChange(of: mosaicX) { _ in applyAllEdits() }
            .onChange(of: mosaicY) { _ in applyAllEdits() }
            .onChange(of: mosaicWidth) { _ in applyAllEdits() }
            .onChange(of: mosaicHeight) { _ in applyAllEdits() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func sliderRow(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        sliderRow(title, value: Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        ), range: Double(range.lowerBound)...Double(range.upperBound))
    }

    private func applyAllEdits() {
        guard let ciInput = ciImage(from: sourceImage) else {
            errorMessage = "无法读取图片"
            return
        }

        var operations: [CMPhotoEditOperation] = []

        operations.append(CMColorAdjustOperation(configuration: .init(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            exposureEV: exposureEV
        )))

        operations.append(CMFilterOperation(filter: selectedFilter.filter))

        if cropEnabled {
            let state = CMCropState(
                imageSize: ciInput.extent.size,
                zoomScale: cropZoom,
                panOffset: CGPoint(x: cropPanX, y: cropPanY),
                rotationDegrees: cropRotation,
                outputAspectRatio: cropAspect.ratio
            )
            operations.append(CMCropOperation(state: state))
        }

        if textEnabled, !overlayText.isEmpty {
            let textOp = CMTextOverlayOperation(configuration: .init(
                text: overlayText,
                normalizedOrigin: CGPoint(x: textX, y: textY),
                fontSize: textSize,
                color: UIColor.white.cgColor
            ))
            operations.append(textOp)
        }

        if mosaicEnabled {
            let extent = ciInput.extent
            let manualRect = CGRect(
                x: extent.minX + extent.width * mosaicX,
                y: extent.minY + extent.height * mosaicY,
                width: extent.width * min(1, mosaicWidth),
                height: extent.height * min(1, mosaicHeight)
            )

            let config = CMMosaicOperation.Configuration(
                manualRegions: [manualRect],
                autoDetectSensitiveData: autoMosaic,
                mosaicScale: mosaicScale
            )

            let detector: CMSensitiveDataDetecting? = {
                if autoMosaic {
                    if #available(iOS 13.0, *) {
                        return CMVisionSensitiveDataDetector()
                    }
                }
                return nil
            }()

            operations.append(CMMosaicOperation(configuration: config, detector: detector))
        }

        do {
            let output = try PhotoEditor.CMPhotoEditor.edit(ciInput, operations: operations)
            if let uiImage = makeUIImage(from: output) {
                previewImage = uiImage
                errorMessage = nil
            }
            else {
                errorMessage = "渲染结果失败"
            }
        }
        catch {
            errorMessage = "编辑失败: \(error.localizedDescription)"
        }
    }

    private func resetAll() {
        brightness = 0
        contrast = 1
        saturation = 1
        exposureEV = 0
        selectedFilter = .none

        cropEnabled = false
        cropZoom = 1
        cropPanX = 0
        cropPanY = 0
        cropRotation = 0
        cropAspect = .square

        textEnabled = false
        overlayText = "CONFIDENTIAL"
        textX = 0.1
        textY = 0.1
        textSize = 28

        mosaicEnabled = false
        autoMosaic = true
        mosaicScale = 24
        mosaicX = 0.2
        mosaicY = 0.2
        mosaicWidth = 0.4
        mosaicHeight = 0.2

        applyAllEdits()
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

    private func makeUIImage(from image: CIImage) -> UIImage? {
        let extent = image.extent.integral
        guard let cg = renderContext.createCGImage(image, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func saveToPhotoLibrary() {
        guard let ciImage = ciImage(from: previewImage) else {
            saveMessage = "无法保存图片"
            return
        }

        isSaving = true
        saveMessage = nil

        CMPhotoEditorSave.saveToPhotoLibrary(ciImage) { result in
            isSaving = false

            switch result {
            case .success:
                saveMessage = "保存成功"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    saveMessage = nil
                }
            case .failure(let error):
                saveMessage = "保存失败: \(error.errorDescription ?? "未知错误")"
            }
        }
    }

    private static func makeSampleImage() -> UIImage {
        let size = CGSize(width: 1200, height: 800)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 68, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 38, weight: .medium),
                .foregroundColor: UIColor.systemYellow,
                .paragraphStyle: paragraph
            ]

            "Comet PhotoEditor Demo".draw(in: CGRect(x: 50, y: 70, width: 1050, height: 100), withAttributes: titleAttrs)
            "Email: demo.user@example.com".draw(in: CGRect(x: 50, y: 210, width: 1000, height: 60), withAttributes: bodyAttrs)
            "Card: 1234567890123456".draw(in: CGRect(x: 50, y: 280, width: 1000, height: 60), withAttributes: bodyAttrs)
            "SSN: 123-45-6789".draw(in: CGRect(x: 50, y: 350, width: 1000, height: 60), withAttributes: bodyAttrs)

            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 50, y: 460, width: 280, height: 220))
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 360, y: 460, width: 280, height: 220))
            UIColor.systemGreen.setFill()
            ctx.fill(CGRect(x: 670, y: 460, width: 280, height: 220))
        }
    }
}

private enum DemoFilter: CaseIterable {
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

private enum DemoAspect: CaseIterable {
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

private struct DemoImagePicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                completion(nil)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.completion(object as? UIImage)
                }
            }
        }
    }
}

#Preview {
    CMPhotoEditorDemo()
}
