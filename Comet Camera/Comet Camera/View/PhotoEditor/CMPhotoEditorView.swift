//
//  CMPhotoEditorView.swift
//  Comet Camera
//
//  Created by 桃园谷 on 2026/3/25.
//

import SwiftUI
import Camera
import PhotoEditor

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

struct CMPhotoEditorView: View {
    @State private var sourceImage: UIImage = Self.makeSampleImage()
    @State private var previewCIImage: CIImage?
    @State private var errorMessage: String?
    @State private var showPicker = false
    @State private var imageContentMode: CMPhotoEditorContentMode = .scaleAspectFit

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
    
    @State private var holeRect: CGRect = CGRect(x: 100, y: 300, width: 200, height: 150)
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    Button(action: {}) {
                        Text("保存")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Color.black.ignoresSafeArea())
                
                ZStack {
                    VStack(spacing: 0) {
                        CMPhotoEditorMetalView(image: previewCIImage, imageContentMode: .scaleAspectFill)
                            .frame(height: 300)
                            .clipShape(.rect)
                            .padding(.horizontal, 2)
                    }
                    .frame(width: geometry.size.width)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .overlay(
//                        Rectangle()
//                            .fill(.ultraThinMaterial)  // 毛玻璃效果
//                            .mask(
//                                Rectangle()
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .frame(width: holeRect.width, height: holeRect.height)
//                                            .position(x: holeRect.midX, y: holeRect.midY)
//                                            .blendMode(.destinationOut)
//                                    )
//                            )
//                            .ignoresSafeArea()
//                    )
//                    HoleMask(
//                        holeRect: holeRect,
//                        screenSize: geometry.size
//                    )
                    
//                    ResizableHole(
//                        rect: $holeRect,
//                        isDragging: $isDragging
//                    )
                }
                CMSmallFilterListView(image: sourceImage.preparingThumbnail(of: .init(width: 30, height: 40))!)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }
        .onAppear {
            applyAllEdits()
        }
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
            previewCIImage = output
            errorMessage = nil
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

    private func saveToPhotoLibrary() {
        guard let ciImage = previewCIImage else {
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
        if let image = UIImage(named: "PreviewImage") {
            return image
        }
        else {
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
}

struct ResizableHoleView: View {
    @Binding var rect: CGRect
    @Binding var isDragging: Bool
    
    let imageFrame: CGRect
    
    private let minSize: CGFloat = 50
    
    @State private var startRect: CGRect = .zero
    @State private var startLocation: CGPoint = .zero
    @State private var activeHandle: HandleType = .none
    
    enum HandleType: Equatable {
        case none
        case topLeft, top, topRight
        case left, right
        case bottomLeft, bottom, bottomRight
        case move
    }
    
    var body: some View {
        ZStack {
            // 镂空边框 - 整体移动
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            handleMoveGesture(value: value)
                        }
                        .onEnded { _ in
                            activeHandle = .none
                            isDragging = false
                        }
                )
            
            // 四角手柄
            ResizeHandle()
                .position(x: 0, y: 0)
                .gesture(resizeGesture(.topLeft))
            
            ResizeHandle()
                .position(x: rect.width, y: 0)
                .gesture(resizeGesture(.topRight))
            
            ResizeHandle()
                .position(x: 0, y: rect.height)
                .gesture(resizeGesture(.bottomLeft))
            
            ResizeHandle()
                .position(x: rect.width, y: rect.height)
                .gesture(resizeGesture(.bottomRight))
            
            // 四边手柄
            EdgeHandle()
                .position(x: rect.width / 2, y: 0)
                .gesture(resizeGesture(.top))
            
            EdgeHandle()
                .position(x: rect.width / 2, y: rect.height)
                .gesture(resizeGesture(.bottom))
            
            EdgeHandle()
                .position(x: 0, y: rect.height / 2)
                .gesture(resizeGesture(.left))
            
            EdgeHandle()
                .position(x: rect.width, y: rect.height / 2)
                .gesture(resizeGesture(.right))
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .shadow(color: .white.opacity(0.5), radius: isDragging ? 20 : 10)
    }
    
    // 整体移动 - 限制在图片内
    private func handleMoveGesture(value: DragGesture.Value) {
        if activeHandle == .none {
            activeHandle = .move
            startRect = rect
        }
        
        guard activeHandle == .move else { return }
        
        var newRect = startRect
        newRect.origin.x = startRect.origin.x + value.translation.width
        newRect.origin.y = startRect.origin.y + value.translation.height
        
        // 限制在图片内
        let maxX = imageFrame.maxX - newRect.width
        let maxY = imageFrame.maxY - newRect.height
        
        newRect.origin.x = max(newRect.origin.x, imageFrame.origin.x)
        newRect.origin.y = max(newRect.origin.y, imageFrame.origin.y)
        newRect.origin.x = min(newRect.origin.x, maxX)
        newRect.origin.y = min(newRect.origin.y, maxY)
        
        rect = newRect
    }
    
    private func resizeGesture(_ handle: HandleType) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if activeHandle == .none {
                    activeHandle = handle
                    startRect = rect
                    startLocation = value.location
                    isDragging = true
                }
                
                guard activeHandle == handle else { return }
                
                let deltaX = value.location.x - startLocation.x
                let deltaY = value.location.y - startLocation.y
                
                var newRect = startRect
                
                switch handle {
                case .topLeft:
                    // 关键修复：固定右下角，调整左上角
                    let maxOriginX = startRect.maxX - minSize
                    let maxOriginY = startRect.maxY - minSize
                    
                    // 计算新的原点（限制不能越过右下角-最小尺寸）
                    let newOriginX = min(startRect.origin.x + deltaX, maxOriginX)
                    let newOriginY = min(startRect.origin.y + deltaY, maxOriginY)
                    
                    // 限制不能超出图片左/上边界
                    let clampedOriginX = max(newOriginX, imageFrame.origin.x)
                    let clampedOriginY = max(newOriginY, imageFrame.origin.y)
                    
                    newRect.origin.x = clampedOriginX
                    newRect.origin.y = clampedOriginY
                    newRect.size.width = startRect.maxX - clampedOriginX
                    newRect.size.height = startRect.maxY - clampedOriginY
                    
                case .topRight:
                    // 固定左下角，调整右上角
                    let minWidth = minSize
                    let maxWidth = imageFrame.maxX - startRect.origin.x
                    
                    let newWidth = max(min(startRect.width + deltaX, maxWidth), minWidth)
                    let maxOriginY = startRect.maxY - minSize
                    let newOriginY = min(startRect.origin.y + deltaY, maxOriginY)
                    let clampedOriginY = max(newOriginY, imageFrame.origin.y)
                    
                    newRect.origin.y = clampedOriginY
                    newRect.size.width = newWidth
                    newRect.size.height = startRect.maxY - clampedOriginY
                    
                case .bottomLeft:
                    // 固定右上角，调整左下角
                    let minHeight = minSize
                    let maxHeight = imageFrame.maxY - startRect.origin.y
//                    let minWidth = minSize
//                    let maxWidth = imageFrame.maxX - startRect.origin.x // 实际上右边固定，所以这是错的
                    
                    // 重新思考：固定右上角意味着右边和上边不动
                    let newOriginX = min(startRect.origin.x + deltaX, startRect.maxX - minSize)
                    let clampedOriginX = max(newOriginX, imageFrame.origin.x)
                    let newHeight = max(min(startRect.height + deltaY, maxHeight), minHeight)
                    
                    newRect.origin.x = clampedOriginX
                    newRect.size.width = startRect.maxX - clampedOriginX
                    newRect.size.height = newHeight
                    
                case .bottomRight:
                    // 固定左上角，调整右下角
                    let maxWidth = imageFrame.maxX - startRect.origin.x
                    let maxHeight = imageFrame.maxY - startRect.origin.y
                    
                    newRect.size.width = max(min(startRect.width + deltaX, maxWidth), minSize)
                    newRect.size.height = max(min(startRect.height + deltaY, maxHeight), minSize)
                    
                case .top:
                    // 固定底边，调整顶边
                    let maxOriginY = startRect.maxY - minSize
                    let newOriginY = min(startRect.origin.y + deltaY, maxOriginY)
                    let clampedOriginY = max(newOriginY, imageFrame.origin.y)
                    
                    newRect.origin.y = clampedOriginY
                    newRect.size.height = startRect.maxY - clampedOriginY
                    
                case .bottom:
                    // 固定顶边，调整底边
                    let maxHeight = imageFrame.maxY - startRect.origin.y
                    newRect.size.height = max(min(startRect.height + deltaY, maxHeight), minSize)
                    
                case .left:
                    // 固定右边，调整左边
                    let maxOriginX = startRect.maxX - minSize
                    let newOriginX = min(startRect.origin.x + deltaX, maxOriginX)
                    let clampedOriginX = max(newOriginX, imageFrame.origin.x)
                    
                    newRect.origin.x = clampedOriginX
                    newRect.size.width = startRect.maxX - clampedOriginX
                    
                case .right:
                    // 固定左边，调整右边
                    let maxWidth = imageFrame.maxX - startRect.origin.x
                    newRect.size.width = max(min(startRect.width + deltaX, maxWidth), minSize)
                    
                default:
                    break
                }
                
                rect = newRect
            }
            .onEnded { _ in
                activeHandle = .none
                isDragging = false
            }
    }
}

// MARK: - 手柄视图
struct ResizeHandle: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .shadow(radius: 2)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
    }
}

struct EdgeHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .shadow(radius: 2)
    }
}

// MARK: - 遮罩层
struct HoleMask: View {
    let holeRect: CGRect
    let screenSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            let fullScreen = Path(CGRect(origin: .zero, size: screenSize))
            context.fill(fullScreen, with: .color(.black.opacity(0.7)))
            
            let hole = Path(roundedRect: holeRect, cornerRadius: 12)
            context.blendMode = .destinationOut
            context.fill(hole, with: .color(.white))
        }
    }
}

// MARK: - 使用示例
struct ImageSpotlightView: View {
    @State private var holeRect: CGRect = CGRect(x: 100, y: 200, width: 150, height: 150)
    @State private var isDragging = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    // 示例图片（实际使用你的图片）
    private let imageSize = CGSize(width: 800, height: 600)
    
    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            
            // 计算图片在屏幕中的实际frame
            let imageFrame = calculateImageFrame(screenSize: screenSize)
            
            ZStack {
                // 背景遮罩（镂空效果）
                HoleMask(
                    holeRect: holeRect,
                    screenSize: screenSize
                )
                
                // 图片内容（在镂空下方）
                Image(systemName: "photo") // 替换为你的图片
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize.width * imageScale,
                           height: imageSize.height * imageScale)
                    .offset(imageOffset)
                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
                    .opacity(0.3) // 示意图片位置
                
                // 可调整大小的镂空矩形
                ResizableHoleView(
                    rect: $holeRect,
                    isDragging: $isDragging,
                    imageFrame: imageFrame
                )
                
                // 调试信息
                VStack {
                    Text("图片范围: \(Int(imageFrame.origin.x)), \(Int(imageFrame.origin.y)) | \(Int(imageFrame.width))×\(Int(imageFrame.height))")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("镂空: \(Int(holeRect.origin.x)), \(Int(holeRect.origin.y)) | \(Int(holeRect.width))×\(Int(holeRect.height))")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                .padding()
                .background(.black.opacity(0.7))
                .cornerRadius(8)
                .position(x: screenSize.width / 2, y: 50)
            }
        }
        .ignoresSafeArea()
    }
    
    // 计算图片在屏幕中的实际frame
    private func calculateImageFrame(screenSize: CGSize) -> CGRect {
        let scaledWidth = imageSize.width * imageScale
        let scaledHeight = imageSize.height * imageScale
        
        // 图片居中显示时的原点
        let originX = (screenSize.width - scaledWidth) / 2 + imageOffset.width
        let originY = (screenSize.height - scaledHeight) / 2 + imageOffset.height
        
        return CGRect(
            x: originX,
            y: originY,
            width: scaledWidth,
            height: scaledHeight
        )
    }
}

class CMPhotoEditViewController: UIViewController {
    let imageView: CMPhotoEditorMTKView = CMPhotoEditorMTKView()
    let originalImage: UIImage
    
    let rulerManager = CMRulerManager()
    private var currentRuler: CMRulerView?
    
    init(image: UIImage) {
        originalImage = image
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let ciInput = CIImage(image: originalImage) else { return }
        
        do {
            let output = try PhotoEditor.CMPhotoEditor.edit(ciInput, operations: [])
            imageView.image = output
        }
        catch {
             print("编辑失败: \(error.localizedDescription)")
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        let size = originalImage.size
        let radio = size.width / size.height
        let imgContainerWidth = view.bounds.width - 60
        let imgContainerHeight = imgContainerWidth / radio
        
        let imageArea = UIView()
        imageArea.translatesAutoresizingMaskIntoConstraints = false
        imageArea.backgroundColor = .clear
        view.addSubview(imageArea)
        
        let imageContainer = UIView()
        imageContainer.backgroundColor = .white
        imageContainer.layer.cornerRadius = 14
        imageContainer.clipsToBounds = true
        imageArea.addSubview(imageContainer)
        
        let borderWidth: CGFloat = 6
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let imageWidth = imgContainerWidth - borderWidth * 2
        let imageHeight = imgContainerHeight - borderWidth * 2
        imageView.frame = .init(x: borderWidth, y: borderWidth, width: imageWidth, height: imageHeight)
        imageView.layer.cornerRadius = 14 - borderWidth / 2
        imageView.clipsToBounds = true
        imageView.imageContentMode = .scaleAspectFill
        
        imageContainer.addSubview(imageView)
        
        let adjuster = UIView()
        view.addSubview(adjuster)
        adjuster.translatesAutoresizingMaskIntoConstraints = false
        adjuster.backgroundColor = .clear
        
        let lensPicker = UIHostingController(
            rootView: CMPhotoEditorAdjustPicker(
                items: rulerManager.items,
                itemDidChanged: updateRulerWhenAdjustChanged
            )
        ).view!
        lensPicker.backgroundColor = .clear
        view.addSubview(lensPicker)
        lensPicker.translatesAutoresizingMaskIntoConstraints = false
        
        let featurePicker = UIHostingController(rootView: CMPhotoEditorFeaturePicker()).view!
        view.addSubview(featurePicker)
        featurePicker.backgroundColor = .clear
        featurePicker.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageContainer.centerXAnchor.constraint(equalTo: imageArea.centerXAnchor),
            imageContainer.centerYAnchor.constraint(equalTo: imageArea.centerYAnchor),
            imageContainer.widthAnchor.constraint(equalToConstant: imgContainerWidth),
            imageContainer.heightAnchor.constraint(equalToConstant: imgContainerHeight),
            
            imageArea.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 30),
            imageArea.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            imageArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageArea.bottomAnchor.constraint(equalTo: lensPicker.topAnchor, constant: -10),
            
            adjuster.heightAnchor.constraint(equalToConstant: 80),
            adjuster.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 30),
            adjuster.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            adjuster.bottomAnchor.constraint(equalTo: lensPicker.topAnchor, constant: -10),
            
            lensPicker.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            lensPicker.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            lensPicker.heightAnchor.constraint(equalToConstant: 40),
            lensPicker.bottomAnchor.constraint(equalTo: featurePicker.topAnchor, constant: -20),
            
            featurePicker.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            featurePicker.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        guard let adjust = rulerManager.items.first,
              let ruler = rulerManager.getRulter(adjust)
        else { return }
        adjuster.addSubview(ruler)
        NSLayoutConstraint.activate([
            ruler.leadingAnchor.constraint(equalTo: adjuster.leadingAnchor),
            ruler.trailingAnchor.constraint(equalTo: adjuster.trailingAnchor),
            ruler.topAnchor.constraint(equalTo: adjuster.topAnchor),
            ruler.bottomAnchor.constraint(equalTo: adjuster.bottomAnchor),
        ])
    }
    
    private func updateRulerWhenAdjustChanged(_ newAdjust: CMPhotoAdjustItem) {
        guard
            let ruler = currentRuler,
            let adjustContainer = ruler.superview,
            let newRuler = rulerManager.getRulter(newAdjust)
        else { return }
        
        ruler.removeFromSuperview()
        adjustContainer.addSubview(newRuler)
        
        NSLayoutConstraint.activate([
            newRuler.leadingAnchor.constraint(equalTo: adjustContainer.leadingAnchor),
            newRuler.trailingAnchor.constraint(equalTo: adjustContainer.trailingAnchor),
            newRuler.topAnchor.constraint(equalTo: adjustContainer.topAnchor),
            newRuler.bottomAnchor.constraint(equalTo: adjustContainer.bottomAnchor),
        ])
    }
}

struct CMPhotoEditViewPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CMPhotoEditViewController {
        let image = UIImage(named: "PreviewImage")!
        let vc = CMPhotoEditViewController(image: image)
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CMPhotoEditViewController, context: Context) {
    
    }
}

#Preview {
//    CMPhotoEditorView()
//    ImageSpotlightView()
//    CMPhotoEditViewPreview()
//        .ignoresSafeArea()
    GeometryReader { geometry in
        Image("abc")
            .frame(width: geometry.size.width, height: geometry.size.height)
    }
}





