# 图片编辑功能完善实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完善图片编辑功能，包括裁剪与保存、滤镜预览、添加滤镜和色彩调整等核心功能

**Architecture:** 基于现有的 PhotoEditor 模块，扩展和增强其功能，确保所有编辑操作都有预览和保存能力，同时提供直观的用户界面

**Tech Stack:** Swift, iOS, Metal (for filters), UIKit

---

## 文件结构

### 核心文件
- `Sources/PhotoEditor/Core/CMPhotoEditorEngine.swift` - 照片编辑引擎核心
- `Sources/PhotoEditor/Operations/CMColorAdjustOperation.swift` - 色彩调整操作
- `Sources/PhotoEditor/Operations/CMFilterOperation.swift` - 滤镜操作
- `Sources/PhotoEditor/Operations/CMCropOperation.swift` - 裁剪操作
- `Sources/PhotoEditor/Support/CMPhotoEditorSave.swift` - 保存功能
- `Sources/PhotoEditor/Models/CMPhotoEditorFilter.swift` - 滤镜模型

### 视图文件
- `Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoEditorView.swift` - 照片编辑主视图
- `Comet Camera/Comet Camera/View/Components/CMPhotoEditSlider.swift` - 编辑滑块组件
- `Comet Camera/Comet Camera/CM CropViewController/CMCropViewController.swift` - 裁剪视图控制器

## 任务分解

### 任务 1: 完善图片裁剪功能

**Files:**
- Modify: `Sources/PhotoEditor/Operations/CMCropOperation.swift`
- Modify: `Comet Camera/Comet Camera/CM CropViewController/CMCropViewController.swift`
- Test: `Tests/PhotoEditorTests/CMCropStateTests.swift`

- [ ] **Step 1: 增强裁剪操作功能**

```swift
// 在 CMCropOperation.swift 中添加更多裁剪选项
extension CMCropOperation {
    func cropImage(_ image: UIImage, to rect: CGRect, withRotation rotation: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let scale = image.scale
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }
        
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)
        
        if rotation != 0 {
            return croppedImage.rotated(by: rotation)
        }
        
        return croppedImage
    }
}
```

- [ ] **Step 2: 改进裁剪视图控制器**

```swift
// 在 CMCropViewController.swift 中添加保存功能
func saveCroppedImage() {
    guard let croppedImage = croppedImage else { return }
    
    PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: croppedImage)
    } completionHandler: { success, error in
        DispatchQueue.main.async {
            if success {
                self.dismiss(animated: true)
            } else {
                // 显示错误信息
            }
        }
    }
}
```

- [ ] **Step 3: 运行测试验证裁剪功能**

Run: `swift test --filter CMCropStateTests`
Expected: PASS

- [ ] **Step 4: 提交更改**

```bash
git add Sources/PhotoEditor/Operations/CMCropOperation.swift Comet Camera/Comet Camera/CM CropViewController/CMCropViewController.swift
git commit -m "feat: enhance crop functionality with rotation and save"
```

### 任务 2: 实现滤镜预览和添加功能

**Files:**
- Modify: `Sources/PhotoEditor/Operations/CMFilterOperation.swift`
- Modify: `Sources/PhotoEditor/Models/CMPhotoEditorFilter.swift`
- Modify: `Comet Camera/Comet Camera/View/CMSmallFilterListView.swift`

- [ ] **Step 1: 扩展滤镜模型**

```swift
// 在 CMPhotoEditorFilter.swift 中添加更多滤镜类型
enum CMPhotoEditorFilterType: String, CaseIterable {
    case normal
    case blackAndWhite
    case sepia
    case vintage
    case chrome
    case fade
    case instant
    case process
    case transfer
    case curve
    case tonal
    case mono
}

extension CMPhotoEditorFilter {
    static func allFilters() -> [CMPhotoEditorFilter] {
        return CMPhotoEditorFilterType.allCases.map { type in
            CMPhotoEditorFilter(type: type, intensity: 1.0)
        }
    }
}
```

- [ ] **Step 2: 实现滤镜预览功能**

```swift
// 在 CMFilterOperation.swift 中添加预览方法
func previewFilter(on image: UIImage, intensity: CGFloat) -> UIImage? {
    // 使用 Metal 或 Core Image 实现实时预览
    // 简化实现，实际项目中使用更高效的渲染方式
    guard let ciImage = CIImage(image: image) else { return nil }
    
    let filter = CIFilter(name: filterType.coreImageFilterName())
    filter?.setValue(ciImage, forKey: kCIInputImageKey)
    filter?.setValue(intensity, forKey: kCIInputIntensityKey)
    
    guard let outputImage = filter?.outputImage else { return nil }
    
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
    
    return UIImage(cgImage: cgImage)
}

// 扩展滤镜类型以获取 Core Image 滤镜名称
extension CMPhotoEditorFilterType {
    func coreImageFilterName() -> String {
        switch self {
        case .normal: return "CIColorControls"
        case .blackAndWhite: return "CIColorMonochrome"
        case .sepia: return "CISepiaTone"
        case .vintage: return "CIPhotoEffectProcess"
        case .chrome: return "CIPhotoEffectChrome"
        case .fade: return "CIPhotoEffectFade"
        case .instant: return "CIPhotoEffectInstant"
        case .process: return "CIPhotoEffectProcess"
        case .transfer: return "CIPhotoEffectTransfer"
        case .curve: return "CIColorCurves"
        case .tonal: return "CIPhotoEffectTonal"
        case .mono: return "CIColorMonochrome"
        }
    }
}
```

- [ ] **Step 3: 改进滤镜选择视图**

```swift
// 在 CMSmallFilterListView.swift 中添加预览功能
func updateFilterPreviews(for image: UIImage) {
    for (index, filter) in filters.enumerated() {
        let previewImage = filter.preview(on: image)
        filterCells[index].previewImage = previewImage
    }
}
```

- [ ] **Step 4: 运行测试验证滤镜功能**

Run: `swift test --filter CMOverlayAndFilterTests`
Expected: PASS

- [ ] **Step 5: 提交更改**

```bash
git add Sources/PhotoEditor/Operations/CMFilterOperation.swift Sources/PhotoEditor/Models/CMPhotoEditorFilter.swift Comet Camera/Comet Camera/View/CMSmallFilterListView.swift
git commit -m "feat: add filter preview and more filter types"
```

### 任务 3: 实现图片色彩调整功能

**Files:**
- Modify: `Sources/PhotoEditor/Operations/CMColorAdjustOperation.swift`
- Modify: `Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoAdjusterView.swift`

- [ ] **Step 1: 增强色彩调整操作**

```swift
// 在 CMColorAdjustOperation.swift 中添加更多调整选项
struct CMColorAdjustments {
    var brightness: CGFloat = 0.0 // -1.0 to 1.0
    var contrast: CGFloat = 1.0   // 0.0 to 2.0
    var saturation: CGFloat = 1.0 // 0.0 to 2.0
    var warmth: CGFloat = 0.0     // -1.0 to 1.0
    var tint: CGFloat = 0.0       // -1.0 to 1.0
}

extension CMColorAdjustOperation {
    func applyAdjustments(_ adjustments: CMColorAdjustments, to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // 应用亮度、对比度、饱和度
        let colorControls = CIFilter(name: "CIColorControls")!
        colorControls.setValue(ciImage, forKey: kCIInputImageKey)
        colorControls.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
        colorControls.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
        colorControls.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
        
        guard var outputImage = colorControls.outputImage else { return nil }
        
        // 应用 warmth 和 tint
        if adjustments.warmth != 0 || adjustments.tint != 0 {
            let colorMatrix = CIFilter(name: "CIColorMatrix")!
            let warmth = adjustments.warmth
            let tint = adjustments.tint
            
            let matrix = CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0)
            let vector = CIVector(x: warmth * 0.1, y: 0.0, z: tint * -0.1, w: 0.0)
            
            colorMatrix.setValue(outputImage, forKey: kCIInputImageKey)
            colorMatrix.setValue(matrix, forKey: "inputRVector")
            colorMatrix.setValue(matrix, forKey: "inputGVector")
            colorMatrix.setValue(matrix, forKey: "inputBVector")
            colorMatrix.setValue(vector, forKey: "inputBiasVector")
            
            outputImage = colorMatrix.outputImage!
        }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
```

- [ ] **Step 2: 改进色彩调整视图**

```swift
// 在 CMPhotoAdjusterView.swift 中添加更多调整滑块
class CMPhotoAdjusterView: UIView {
    private let brightnessSlider = CMPhotoEditSlider(title: "亮度")
    private let contrastSlider = CMPhotoEditSlider(title: "对比度")
    private let saturationSlider = CMPhotoEditSlider(title: "饱和度")
    private let warmthSlider = CMPhotoEditSlider(title: "色温")
    private let tintSlider = CMPhotoEditSlider(title: "色调")
    
    var adjustments: CMColorAdjustments = CMColorAdjustments() {
        didSet {
            updateSliders()
        }
    }
    
    var adjustmentChanged: ((CMColorAdjustments) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupSliders()
    }
    
    private func setupUI() {
        // 添加滑块到视图
        let stackView = UIStackView(arrangedSubviews: [brightnessSlider, contrastSlider, saturationSlider, warmthSlider, tintSlider])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    private func setupSliders() {
        brightnessSlider.range = -1.0...1.0
        brightnessSlider.value = 0.0
        brightnessSlider.valueChanged = { [weak self] value in
            self?.adjustments.brightness = value
            self?.adjustmentChanged?(self?.adjustments ?? CMColorAdjustments())
        }
        
        contrastSlider.range = 0.0...2.0
        contrastSlider.value = 1.0
        contrastSlider.valueChanged = { [weak self] value in
            self?.adjustments.contrast = value
            self?.adjustmentChanged?(self?.adjustments ?? CMColorAdjustments())
        }
        
        saturationSlider.range = 0.0...2.0
        saturationSlider.value = 1.0
        saturationSlider.valueChanged = { [weak self] value in
            self?.adjustments.saturation = value
            self?.adjustmentChanged?(self?.adjustments ?? CMColorAdjustments())
        }
        
        warmthSlider.range = -1.0...1.0
        warmthSlider.value = 0.0
        warmthSlider.valueChanged = { [weak self] value in
            self?.adjustments.warmth = value
            self?.adjustmentChanged?(self?.adjustments ?? CMColorAdjustments())
        }
        
        tintSlider.range = -1.0...1.0
        tintSlider.value = 0.0
        tintSlider.valueChanged = { [weak self] value in
            self?.adjustments.tint = value
            self?.adjustmentChanged?(self?.adjustments ?? CMColorAdjustments())
        }
    }
    
    private func updateSliders() {
        brightnessSlider.value = adjustments.brightness
        contrastSlider.value = adjustments.contrast
        saturationSlider.value = adjustments.saturation
        warmthSlider.value = adjustments.warmth
        tintSlider.value = adjustments.tint
    }
}
```

- [ ] **Step 3: 运行测试验证色彩调整功能**

Run: `swift test --filter CMPhotoEditorEngineTests`
Expected: PASS

- [ ] **Step 4: 提交更改**

```bash
git add Sources/PhotoEditor/Operations/CMColorAdjustOperation.swift Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoAdjusterView.swift
git commit -m "feat: add comprehensive color adjustment controls"
```

### 任务 4: 完善图片保存功能

**Files:**
- Modify: `Sources/PhotoEditor/Support/CMPhotoEditorSave.swift`
- Modify: `Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoEditorView.swift`

- [ ] **Step 1: 增强保存功能**

```swift
// 在 CMPhotoEditorSave.swift 中添加更多保存选项
enum CMPhotoSaveFormat: String {
    case jpeg
    case png
    case heic
}

extension CMPhotoEditorSave {
    static func save(image: UIImage, format: CMPhotoSaveFormat, quality: CGFloat = 0.8, completion: @escaping (URL?, Error?) -> Void) {
        var data: Data?
        
        switch format {
        case .jpeg:
            data = image.jpegData(compressionQuality: quality)
        case .png:
            data = image.pngData()
        case .heic:
            if #available(iOS 11.0, *) {
                let ciImage = CIImage(image: image)
                let context = CIContext()
                data = context.heifRepresentation(of: ciImage!, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
            } else {
                data = image.jpegData(compressionQuality: quality)
            }
        }
        
        guard let imageData = data else {
            completion(nil, NSError(domain: "CMPhotoEditor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"]))
            return
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "edited_\(UUID().uuidString).\(format.rawValue)"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            completion(fileURL, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    static func saveToPhotoLibrary(image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            completion(success, error)
        }
    }
}
```

- [ ] **Step 2: 改进照片编辑视图**

```swift
// 在 CMPhotoEditorView.swift 中添加保存按钮和功能
class CMPhotoEditorView: UIView {
    private let saveButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSaveButton()
    }
    
    private func setupSaveButton() {
        saveButton.setTitle("保存", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 8
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(saveButton)
        NSLayoutConstraint.activate([
            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    @objc private func saveButtonTapped() {
        guard let editedImage = currentEditedImage else { return }
        
        // 显示保存选项
        let alertController = UIAlertController(title: "保存图片", message: "选择保存位置", preferredStyle: .actionSheet)
        
        let saveToLibraryAction = UIAlertAction(title: "保存到相册", style: .default) { _ in
            CMPhotoEditorSave.saveToPhotoLibrary(image: editedImage) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // 显示成功提示
                    } else {
                        // 显示错误提示
                    }
                }
            }
        }
        
        let saveToFileAction = UIAlertAction(title: "保存到文件", style: .default) { _ in
            CMPhotoEditorSave.save(image: editedImage, format: .jpeg) { url, error in
                DispatchQueue.main.async {
                    if let url = url {
                        // 显示文件保存成功提示
                    } else {
                        // 显示错误提示
                    }
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        alertController.addAction(saveToLibraryAction)
        alertController.addAction(saveToFileAction)
        alertController.addAction(cancelAction)
        
        // 显示 alertController
        if let viewController = self.window?.rootViewController {
            viewController.present(alertController, animated: true)
        }
    }
}
```

- [ ] **Step 3: 运行测试验证保存功能**

Run: `swift test --filter CMPhotoEditorEngineTests`
Expected: PASS

- [ ] **Step 4: 提交更改**

```bash
git add Sources/PhotoEditor/Support/CMPhotoEditorSave.swift Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoEditorView.swift
git commit -m "feat: enhance save functionality with multiple formats and locations"
```

### 任务 5: 集成所有功能并优化用户体验

**Files:**
- Modify: `Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoEditorView.swift`
- Modify: `Sources/PhotoEditor/Core/CMPhotoEditorEngine.swift`

- [ ] **Step 1: 集成所有编辑功能**

```swift
// 在 CMPhotoEditorView.swift 中集成所有编辑功能
class CMPhotoEditorView: UIView {
    private let cropButton = UIButton(type: .system)
    private let filterButton = UIButton(type: .system)
    private let adjustButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    private let filterListView = CMSmallFilterListView()
    private let adjusterView = CMPhotoAdjusterView()
    
    private var currentMode: EditMode = .none
    private var originalImage: UIImage
    private var currentEditedImage: UIImage
    
    enum EditMode {
        case none
        case crop
        case filter
        case adjust
    }
    
    init(image: UIImage) {
        self.originalImage = image
        self.currentEditedImage = image
        super.init(frame: .zero)
        setupUI()
        setupButtons()
        setupSubviews()
    }
    
    private func setupUI() {
        // 设置背景和基本布局
        backgroundColor = .black
    }
    
    private func setupButtons() {
        // 设置底部工具栏按钮
        let buttonStackView = UIStackView(arrangedSubviews: [cropButton, filterButton, adjustButton, saveButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .equalSpacing
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(buttonStackView)
        NSLayoutConstraint.activate([
            buttonStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 配置按钮
        cropButton.setTitle("裁剪", for: .normal)
        cropButton.setTitleColor(.white, for: .normal)
        cropButton.addTarget(self, action: #selector(cropButtonTapped), for: .touchUpInside)
        
        filterButton.setTitle("滤镜", for: .normal)
        filterButton.setTitleColor(.white, for: .normal)
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        
        adjustButton.setTitle("调整", for: .normal)
        adjustButton.setTitleColor(.white, for: .normal)
        adjustButton.addTarget(self, action: #selector(adjustButtonTapped), for: .touchUpInside)
        
        saveButton.setTitle("保存", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }
    
    private func setupSubviews() {
        // 设置滤镜列表
        filterListView.translatesAutoresizingMaskIntoConstraints = false
        filterListView.isHidden = true
        addSubview(filterListView)
        NSLayoutConstraint.activate([
            filterListView.leadingAnchor.constraint(equalTo: leadingAnchor),
            filterListView.trailingAnchor.constraint(equalTo: trailingAnchor),
            filterListView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            filterListView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        // 设置调整视图
        adjusterView.translatesAutoresizingMaskIntoConstraints = false
        adjusterView.isHidden = true
        addSubview(adjusterView)
        NSLayoutConstraint.activate([
            adjusterView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adjusterView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adjusterView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            adjusterView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // 设置回调
        filterListView.filterSelected = { [weak self] filter in
            guard let self = self else { return }
            let operation = CMFilterOperation(filter: filter)
            self.currentEditedImage = operation.apply(to: self.currentEditedImage) ?? self.currentEditedImage
            self.updateImageView()
        }
        
        adjusterView.adjustmentChanged = { [weak self] adjustments in
            guard let self = self else { return }
            let operation = CMColorAdjustOperation(adjustments: adjustments)
            self.currentEditedImage = operation.apply(to: self.currentEditedImage) ?? self.currentEditedImage
            self.updateImageView()
        }
    }
    
    @objc private func cropButtonTapped() {
        // 打开裁剪视图控制器
        let cropViewController = CMCropViewController(image: currentEditedImage)
        cropViewController.delegate = self
        // 显示裁剪视图控制器
        if let viewController = self.window?.rootViewController {
            viewController.present(cropViewController, animated: true)
        }
    }
    
    @objc private func filterButtonTapped() {
        toggleMode(.filter)
    }
    
    @objc private func adjustButtonTapped() {
        toggleMode(.adjust)
    }
    
    private func toggleMode(_ mode: EditMode) {
        // 隐藏所有子视图
        filterListView.isHidden = true
        adjusterView.isHidden = true
        
        // 显示选中的模式
        switch mode {
        case .filter:
            filterListView.isHidden = false
            filterListView.updateFilterPreviews(for: currentEditedImage)
        case .adjust:
            adjusterView.isHidden = false
        default:
            break
        }
        
        currentMode = mode
    }
    
    private func updateImageView() {
        // 更新显示的图片
        // 实现细节取决于具体的图片显示方式
    }
}

// 实现裁剪视图控制器代理
extension CMPhotoEditorView: CMCropViewControllerDelegate {
    func cropViewController(_ controller: CMCropViewController, didCropTo image: UIImage, with rect: CGRect, angle: CGFloat) {
        currentEditedImage = image
        updateImageView()
        controller.dismiss(animated: true)
    }
    
    func cropViewControllerDidCancel(_ controller: CMCropViewController) {
        controller.dismiss(animated: true)
    }
}
```

- [ ] **Step 2: 优化编辑引擎性能**

```swift
// 在 CMPhotoEditorEngine.swift 中添加缓存和性能优化
class CMPhotoEditorEngine {
    private var operationCache: [String: UIImage] = [:]
    
    func applyOperations(_ operations: [CMPhotoEditOperation], to image: UIImage) -> UIImage {
        var currentImage = image
        
        for operation in operations {
            let cacheKey = "\(operation.operationType)-\(operation.hashValue)"
            
            if let cachedImage = operationCache[cacheKey] {
                currentImage = cachedImage
            } else {
                let processedImage = operation.apply(to: currentImage) ?? currentImage
                operationCache[cacheKey] = processedImage
                currentImage = processedImage
            }
        }
        
        return currentImage
    }
    
    func clearCache() {
        operationCache.removeAll()
    }
}

// 为操作添加哈希值计算
extension CMPhotoEditOperation {
    var operationType: String {
        return String(describing: type(of: self))
    }
    
    override var hashValue: Int {
        return operationType.hashValue
    }
}
```

- [ ] **Step 3: 运行完整测试套件**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 4: 提交更改**

```bash
git add Comet Camera/Comet Camera/View/PhotoEditor/CMPhotoEditorView.swift Sources/PhotoEditor/Core/CMPhotoEditorEngine.swift
git commit -m "feat: integrate all editing features and optimize user experience"
```

---

## 执行选项

**Plan complete and saved to `docs/superpowers/plans/2026-04-14-photo-editor-enhancements.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**