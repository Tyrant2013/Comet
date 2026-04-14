//
//  CMPhotoEditorView.swift
//  Comet Camera
//

import SwiftUI
import Camera
import PhotoEditor
import UIKit

class CMPhotoEditViewController: UIViewController, CMCropViewControllerDelegate {
    let imageView: CMPhotoEditorMTKView = CMPhotoEditorMTKView()
    
    let rulerManager = CMRulerManager()
    private var currentRuler: CMRulerView
    
    private var currentAdjust: CMPhotoAdjustItem
    
    private var editContext: CMPhotoEditContext
    private let editEngine = CMPhotoEditorEngine()
    
    private var brightnessValue: Double = 0
    private var contrastValue: Double = 1
    private var saturationValue: Double = 1
    private var exposureEVValue: Double = 0
    
    private let cropButton = UIButton(type: .system)
    private let filterButton = UIButton(type: .system)
    private let adjustButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    private let filterListView = CMSmallFilterListView()
    private let adjusterView = CMPhotoAdjusterView()
    
    private var currentMode: EditMode = .none
    private var originalImage: UIImage
    
    enum EditMode {
        case none
        case crop
        case filter
        case adjust
    }
    
    init(image: UIImage) {
        self.originalImage = image
        editContext = CMPhotoEditContext(image: CIImage(image: image)!)
        currentAdjust = .defaultAdjustItem()
        currentRuler = rulerManager.getRulter(currentAdjust)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupButtons()
        setupSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        apply()
    }
    
    private func apply() {
        do {
            // 每次应用操作前重置图像到原始状态
            editContext.resetImage()
            
            var operations: [any CMPhotoEditOperation] = []
            
            let colorAdjustOp = CMColorAdjustOperation(
                configuration: .init(
                    brightness: brightnessValue,
                    contrast: contrastValue,
                    saturation: saturationValue,
                    exposureEV: exposureEVValue
                )
            )
            operations.append(colorAdjustOp)
            
            imageView.image = try editEngine.run(operations: operations, context: &editContext)
        }
        catch {
            
        }
    }
    
    private func setupButtons() {
        // 设置底部工具栏按钮
        let buttonStackView = UIStackView(arrangedSubviews: [cropButton, filterButton, adjustButton, saveButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .equalSpacing
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(buttonStackView)
        NSLayoutConstraint.activate([
            buttonStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
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
        view.addSubview(filterListView)
        NSLayoutConstraint.activate([
            filterListView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterListView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterListView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            filterListView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        // 设置调整视图
        adjusterView.translatesAutoresizingMaskIntoConstraints = false
        adjusterView.isHidden = true
        view.addSubview(adjusterView)
        NSLayoutConstraint.activate([
            adjusterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            adjusterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            adjusterView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            adjusterView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // 设置回调
        filterListView.filterSelected = { [weak self] filter in
            guard let self = self else { return }
            let operation = CMFilterOperation(filter: filter)
            do {
                try operation.apply(to: &self.editContext)
                self.imageView.image = self.editContext.image
            } catch {
                print("Error applying filter: \(error)")
            }
        }
        
        adjusterView.adjustmentChanged = { [weak self] adjustments in
            guard let self = self else { return }
            self.brightnessValue = Double(adjustments.brightness)
            self.contrastValue = Double(adjustments.contrast)
            self.saturationValue = Double(adjustments.saturation)
            self.apply()
        }
    }
    
    @objc private func cropButtonTapped() {
        // 打开裁剪视图控制器
        let cropViewController = CMCropViewController(image: UIImage(ciImage: editContext.image))
        cropViewController.delegate = self
        // 显示裁剪视图控制器
        present(cropViewController, animated: true)
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
            filterListView.updateFilterPreviews(for: UIImage(ciImage: editContext.image))
        case .adjust:
            adjusterView.isHidden = false
        default:
            break
        }
        
        currentMode = mode
    }
    
    // 实现裁剪视图控制器代理
    func cropViewController(_ controller: CMCropViewController, didCropTo image: UIImage, with rect: CGRect, angle: CGFloat) {
        editContext = CMPhotoEditContext(image: CIImage(image: image)!)
        imageView.image = editContext.image
        controller.dismiss(animated: true)
    }
    
    func cropViewControllerDidCancel(_ controller: CMCropViewController) {
        controller.dismiss(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        let size = editContext.image.extent.size
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
        adjuster.clipsToBounds = true
        
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
        
        setupSaveButton()
        
        NSLayoutConstraint.activate([
            imageContainer.centerXAnchor.constraint(equalTo: imageArea.centerXAnchor),
            imageContainer.centerYAnchor.constraint(equalTo: imageArea.centerYAnchor),
            imageContainer.widthAnchor.constraint(equalToConstant: imgContainerWidth),
            imageContainer.heightAnchor.constraint(equalToConstant: imgContainerHeight),
            
            imageArea.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 30),
            imageArea.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            imageArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageArea.bottomAnchor.constraint(equalTo: lensPicker.topAnchor, constant: -10),
            
            adjuster.heightAnchor.constraint(equalToConstant: 110),
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
        
        adjuster.addSubview(currentRuler)
        NSLayoutConstraint.activate([
            currentRuler.leadingAnchor.constraint(equalTo: adjuster.leadingAnchor),
            currentRuler.trailingAnchor.constraint(equalTo: adjuster.trailingAnchor),
            currentRuler.topAnchor.constraint(equalTo: adjuster.topAnchor),
            currentRuler.bottomAnchor.constraint(equalTo: adjuster.bottomAnchor),
        ])
        updateValueChangedObserver()
    }
    

    
    @objc private func saveButtonTapped() {
        guard let currentImage = imageView.image else { return }
        
        let alertController = UIAlertController(title: "保存图片", message: "选择保存位置", preferredStyle: .actionSheet)
        
        let saveToLibraryAction = UIAlertAction(title: "保存到相册", style: .default) { _ in
            CMPhotoEditorSave.saveToPhotoLibrary(image: UIImage(ciImage: currentImage)) { success, error in
                DispatchQueue.main.async {
                    if success {
                        let successAlert = UIAlertController(title: "成功", message: "图片已保存到相册", preferredStyle: .alert)
                        successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(successAlert, animated: true)
                    } else {
                        let errorAlert = UIAlertController(title: "错误", message: "保存失败: \(error?.localizedDescription ?? "未知错误")", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
        
        let saveToFileAction = UIAlertAction(title: "保存到文件", style: .default) { _ in
            CMPhotoEditorSave.save(image: UIImage(ciImage: currentImage), format: .jpeg) { url, error in
                DispatchQueue.main.async {
                    if let url = url {
                        let successAlert = UIAlertController(title: "成功", message: "图片已保存到文件: \(url.lastPathComponent)", preferredStyle: .alert)
                        successAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(successAlert, animated: true)
                    } else {
                        let errorAlert = UIAlertController(title: "错误", message: "保存失败: \(error?.localizedDescription ?? "未知错误")", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "确定", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        alertController.addAction(saveToLibraryAction)
        alertController.addAction(saveToFileAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func updateValueChangedObserver() {
        currentRuler.configuration.valueChanged = componentValueChanged(_:)
    }
    // 调整图片时，各种参数值更新
    private func componentValueChanged(_ value: Int) {
        switch currentAdjust.id {
        case .brightness:
            brightnessValue = Double(value) / 100
            print("brightne:", brightnessValue)
        default:
            break
        }
        apply()
    }
    
    private func updateRulerWhenAdjustChanged(_ newAdjust: CMPhotoAdjustItem) {
        guard let adjustContainer = currentRuler.superview
        else { return }
        
        let newRuler = rulerManager.getRulter(newAdjust)
        adjustContainer.addSubview(newRuler)
        
        NSLayoutConstraint.activate([
            newRuler.leadingAnchor.constraint(equalTo: adjustContainer.leadingAnchor),
            newRuler.trailingAnchor.constraint(equalTo: adjustContainer.trailingAnchor),
            newRuler.topAnchor.constraint(equalTo: adjustContainer.topAnchor),
            newRuler.bottomAnchor.constraint(equalTo: adjustContainer.bottomAnchor),
        ])
        let transform = CGAffineTransformMakeTranslation(0, 120)
        newRuler.transform = transform
        
        UIView.animate(withDuration: 0.2, delay: 0) {
            self.currentRuler.transform = transform
            newRuler.transform = .identity
        } completion: { _ in
            self.currentRuler.configuration.valueChanged = { _ in }
            self.currentRuler.removeFromSuperview()
            self.currentRuler = newRuler
            self.updateValueChangedObserver()
        }
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
    CMPhotoEditViewPreview()
        .ignoresSafeArea()
//    GeometryReader { geometry in
//        Image("abc")
//            .frame(width: geometry.size.width, height: geometry.size.height)
//    }
}





