import UIKit
import Vision
import CoreImage

// MARK: - 主体提取管理器
@available(iOS 17.0, *)
class SubjectLifter {
    
    static let shared = SubjectLifter()
    
    /// 从图片中提取所有主体
    func extractSubject(from image: UIImage, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // 提取所有检测到的主体（index 0 是背景，1+ 是各个主体）
                let allInstances = result.allInstances
                guard allInstances.count > 1 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // ✅ 修正：直接使用 allInstances（已经是 IndexSet），排除背景 0
                var subjectIndices = allInstances
                subjectIndices.remove(0) // 移除背景
                
                let maskPixelBuffer = try result.generateScaledMaskForImage(
                    forInstances: subjectIndices,
                    from: handler
                )
                
                let maskedImage = self.applyMask(maskPixelBuffer, to: image)
                
                DispatchQueue.main.async {
                    completion(maskedImage)
                }
                
            } catch {
                print("Vision 请求失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// 提取点击位置的主体
    func extractSingleSubject(from image: UIImage, at point: CGPoint, completion: @escaping (UIImage?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                
                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let allInstances = result.allInstances
                
                // ✅ 修正：获取点击位置对应的实例索引
                let targetIndex = self.findInstanceIndex(at: point, observation: result, imageSize: image.size, allInstances: allInstances)
                
                guard targetIndex > 0 else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // ✅ 修正：创建只包含单个索引的 IndexSet
                var singleIndexSet = IndexSet()
                singleIndexSet.insert(targetIndex)
                
                let maskPixelBuffer = try result.generateScaledMaskForImage(
                    forInstances: singleIndexSet,
                    from: handler
                )
                
                let maskedImage = self.applyMask(maskPixelBuffer, to: image)
                
                DispatchQueue.main.async {
                    completion(maskedImage)
                }
                
            } catch {
                print("提取失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    // MARK: - 私有方法
    
    /// 通过分析 mask 数据查找点击位置对应的实例索引
    private func findInstanceIndex(at point: CGPoint, observation: VNInstanceMaskObservation, imageSize: CGSize, allInstances: IndexSet) -> Int {
        // 归一化坐标转像素坐标（Vision 使用左下角原点）
        let pixelX = Int(point.x * imageSize.width)
        let pixelY = Int((1.0 - point.y) * imageSize.height)
        
        // 获取原始 mask 的尺寸
        let maskPixelBuffer = observation.instanceMask
        let maskWidth = CVPixelBufferGetWidth(maskPixelBuffer)
        let maskHeight = CVPixelBufferGetHeight(maskPixelBuffer)
        
        // 将点击坐标映射到 mask 坐标系
        let maskX = Int(Double(pixelX) / imageSize.width * Double(maskWidth))
        let maskY = Int(Double(pixelY) / imageSize.height * Double(maskHeight))
        
        // 锁定 pixel buffer
        CVPixelBufferLockBaseAddress(maskPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskPixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(maskPixelBuffer) else {
            // ✅ 修正：使用 first(where:) 获取第一个大于0的元素
            return allInstances.first(where: { $0 > 0 }) ?? 0
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskPixelBuffer)
        
        // 确保坐标在有效范围内
        let clampedX = max(0, min(maskX, maskWidth - 1))
        let clampedY = max(0, min(maskY, maskHeight - 1))
        
        // 读取像素值（32位整数）
        let pixelData = baseAddress.advanced(by: clampedY * bytesPerRow + clampedX * 4)
        let instanceIndex = pixelData.load(as: UInt32.self)
        
        // 如果点击的是背景(0)，返回第一个前景主体
        if instanceIndex == 0 {
            // ✅ 修正：使用 first(where:) 获取第一个大于0的元素
            return allInstances.first(where: { $0 > 0 }) ?? 0
        }
        
        return Int(instanceIndex)
    }
    
    /// 应用遮罩到图片
    private func applyMask(_ maskBuffer: CVPixelBuffer, to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        
        // 创建 CIImage
        var maskCIImage = CIImage(cvPixelBuffer: maskBuffer)
        
        // 调整遮罩大小以匹配原图
        let scaleX = CGFloat(cgImage.width) / CGFloat(width)
        let scaleY = CGFloat(cgImage.height) / CGFloat(height)
        maskCIImage = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // 原图
        let inputCIImage = CIImage(cgImage: cgImage)
        
        // 使用 CIFilter 合成
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
        blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)
        
        guard let outputImage = blendFilter.outputImage else { return nil }
        
        // 创建透明背景
        let context = CIContext(options: nil)
        guard let cgOutputImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgOutputImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - 支持长按提取主体的图片视图
@available(iOS 17.0, *)
class SubjectExtractableImageView: UIImageView {
    
    private var longPressGesture: UILongPressGestureRecognizer!
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    private var isProcessing = false
    
    /// 提取完成回调
    var onSubjectExtracted: ((UIImage, CGPoint) -> Void)?
    /// 提取失败回调
    var onExtractionFailed: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isUserInteractionEnabled = true
        contentMode = .scaleAspectFit
        
        // 长按手势
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.allowableMovement = 50
        addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let image = image, !isProcessing else { return }
        
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            // 触觉反馈
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator?.prepare()
            feedbackGenerator?.impactOccurred()
            
            // 视觉反馈
            animatePress(at: location)
            
            // 开始提取
            isProcessing = true
            extractSubject(at: location)
            
        case .ended, .cancelled:
            removePressAnimation()
            
        default:
            break
        }
    }
    
    private func extractSubject(at point: CGPoint) {
        // 转换坐标到图片坐标系
        guard let imageSize = image?.size else {
            isProcessing = false
            return
        }
        
        let normalizedPoint = convertToNormalizedPoint(viewPoint: point, imageSize: imageSize)
        
        SubjectLifter.shared.extractSingleSubject(from: image!, at: normalizedPoint) { [weak self] extractedImage in
            self?.isProcessing = false
            self?.removePressAnimation()
            
            if let extractedImage = extractedImage {
                self?.onSubjectExtracted?(extractedImage, point)
            } else {
                self?.onExtractionFailed?()
            }
        }
    }
    
    /// 将视图坐标转换为归一化坐标（0-1）
    private func convertToNormalizedPoint(viewPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        let viewSize = bounds.size
        
        // 计算实际显示的图片区域（scaleAspectFit 模式下）
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displayRect: CGRect
        
        if imageAspect > viewAspect {
            // 图片更宽，左右填满，上下留白
            let height = viewSize.width / imageAspect
            let y = (viewSize.height - height) / 2
            displayRect = CGRect(x: 0, y: y, width: viewSize.width, height: height)
        } else {
            // 图片更高，上下填满，左右留白
            let width = viewSize.height * imageAspect
            let x = (viewSize.width - width) / 2
            displayRect = CGRect(x: x, y: 0, width: width, height: viewSize.height)
        }
        
        // 检查点击是否在图片区域内
        guard displayRect.contains(viewPoint) else {
            return CGPoint(x: 0.5, y: 0.5) // 默认中心点
        }
        
        // 转换为图片内相对坐标
        let relativeX = (viewPoint.x - displayRect.minX) / displayRect.width
        let relativeY = (viewPoint.y - displayRect.minY) / displayRect.height
        
        // Vision 框架使用左下角为原点的坐标系，需要翻转 Y 轴
        return CGPoint(x: relativeX, y: 1 - relativeY)
    }
    
    // MARK: - 动画效果
    
    private func animatePress(at location: CGPoint) {
        // 创建涟漪效果
        let ripple = CAShapeLayer()
        ripple.name = "ripple"
        ripple.fillColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        let path = UIBezierPath(arcCenter: location, radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ripple.path = path.cgPath
        
        layer.addSublayer(ripple)
        
        // 扩散动画
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = path.cgPath
        animation.toValue = UIBezierPath(arcCenter: location, radius: 100, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1
        fadeAnimation.toValue = 0
        fadeAnimation.duration = 0.3
        
        ripple.add(animation, forKey: "expand")
        ripple.add(fadeAnimation, forKey: "fade")
    }
    
    private func removePressAnimation() {
        layer.sublayers?.filter { $0.name == "ripple" }.forEach { $0.removeFromSuperlayer() }
    }
}

// MARK: - 拖拽预览视图（提取后的悬浮效果）
class FloatingSubjectView: UIView {
    
    private let imageView: UIImageView
    private var startLocation: CGPoint?
    
    var onDrop: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?
    
    init(image: UIImage) {
        self.imageView = UIImageView(image: image)
        super.init(frame: .zero)
        
        setupUI()
        setupGestures()
        
        // 添加阴影和圆角
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 10
        layer.cornerRadius = 12
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // 默认大小
        bounds = CGRect(x: 0, y: 0, width: 200, height: 200)
    }
    
    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: superview)
        
        switch gesture.state {
        case .began:
            startLocation = center
            
            // 放大动画
            UIView.animate(withDuration: 0.2) {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
            
        case .changed:
            center = location
            
        case .ended, .cancelled:
            // 判断是否拖出有效区域
            let dropLocation = gesture.location(in: superview)
            onDrop?(dropLocation)
            
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onCancel?()
    }
}

// MARK: - 在图片浏览器中集成
extension CMPhotoBrowserViewController {
    
    func setupSubjectExtraction() {
        // 在 cellForItemAt 中配置 Cell
    }
}

// MARK: - 使用示例
@available(iOS 17.0, *)
class SubjectExtractionDemoViewController: UIViewController {
    
    private let imageView = SubjectExtractableImageView(frame: .zero)
    private var floatingView: FloatingSubjectView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // 设置图片
        imageView.image = UIImage(named: "abc.jpg", in: .module, with: nil)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        // 配置回调
        imageView.onSubjectExtracted = { [weak self] extractedImage, location in
            self?.showFloatingSubject(extractedImage, at: location)
        }
        
        imageView.onExtractionFailed = { [weak self] in
            self?.showExtractionFailed()
        }
        
        // 添加提示标签
        let tipLabel = UILabel()
        tipLabel.text = "长按图片提取主体"
        tipLabel.textColor = .secondaryLabel
        tipLabel.textAlignment = .center
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)
        
        NSLayoutConstraint.activate([
            tipLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            tipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func showFloatingSubject(_ image: UIImage, at point: CGPoint) {
        // 移除之前的
        floatingView?.removeFromSuperview()
        
        // 创建悬浮视图
        let floating = FloatingSubjectView(image: image)
        floating.center = point
        view.addSubview(floating)
        self.floatingView = floating
        
        // 入场动画
        floating.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        floating.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
            floating.transform = .identity
            floating.alpha = 1
        })
        
        floating.onDrop = { [weak self] location in
            // 处理放置逻辑
            self?.handleDrop(image: image, at: location)
        }
        
        floating.onCancel = { [weak self] in
            self?.dismissFloatingView()
        }
    }
    
    private func dismissFloatingView() {
        UIView.animate(withDuration: 0.2, animations: {
            self.floatingView?.alpha = 0
            self.floatingView?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in
            self.floatingView?.removeFromSuperview()
            self.floatingView = nil
        }
    }
    
    private func handleDrop(image: UIImage, at location: CGPoint) {
        // 实现你的业务逻辑：保存、分享、拖拽到其他应用等
        print("图片被放置在: \(location)")
        
        // 成功提示
        let alert = UIAlertController(title: "提取成功", message: "主体已提取", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
        
        dismissFloatingView()
    }
    
    private func showExtractionFailed() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        let alert = UIAlertController(title: "未检测到主体", message: "请尝试长按图片中的主要物体", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}


import SwiftUI

@available(iOS 17.0, *)
struct SubjectView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SubjectExtractionDemoViewController {
        let vc = SubjectExtractionDemoViewController()
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: SubjectExtractionDemoViewController, context: Context) {
        
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        SubjectView()
    } else {
        // Fallback on earlier versions
    }
}
