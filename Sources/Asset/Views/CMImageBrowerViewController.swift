//
//  CMImageBrowerViewController.swift
//  Comet
//
//  Created by 桃园谷 on 2026/3/23.
//

import UIKit

public class CMImageBrowserViewController: UIViewController {
    
    // MARK: 配置
    private let configuration = CMBrowserConfiguration()
    
    // MARK: 数据源
    private var images: [UIImage]
    private var currentIndex: Int
    
    // MARK: UI 组件
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .white
        return scrollView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let control = UIPageControl()
        control.numberOfPages = images.count
        control.currentPage = currentIndex
        control.pageIndicatorTintColor = .white.withAlphaComponent(0.5)
        control.currentPageIndicatorTintColor = .white
        control.translatesAutoresizingMaskIntoConstraints = false
        control.isHidden = images.count <= 1
        return control
    }()
    
    private var imageViews: [CMZoomableImageView] = []
    private var panGesture: UIPanGestureRecognizer!
    
    // MARK: 状态
    private var isDraggingToDismiss = false
    private var dismissProgress: CGFloat = 0
    private var initialTouchPoint: CGPoint = .zero
    
    // MARK: 初始化
    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.currentIndex = initialIndex
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewContentSize()
        scrollToIndex(currentIndex, animated: false)
    }
    
    // MARK: 设置 UI
    private func setupUI() {
        view.backgroundColor = .white
        
        // 添加 ScrollView
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 添加 PageControl
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // 创建图片视图
        setupImageViews()
    }
    
    private func setupImageViews() {
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        
        for (index, image) in images.enumerated() {
            let imageView = CMZoomableImageView(image: image)
            imageView.tag = index
            imageView.zoomDelegate = self
            scrollView.addSubview(imageView)
            imageViews.append(imageView)
        }
    }
    
    private func updateScrollViewContentSize() {
        let width = view.bounds.width
        let height = view.bounds.height
        
        scrollView.contentSize = CGSize(width: width * CGFloat(images.count), height: height)
        
        for (index, imageView) in imageViews.enumerated() {
            imageView.frame = CGRect(
                x: width * CGFloat(index),
                y: 0,
                width: width,
                height: height
            )
        }
    }
    
    private func setupGestures() {
        // 下滑关闭手势
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        // 双击手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }
    
    // MARK: 手势处理
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let currentImageView = imageViews[currentIndex]
        
        // 如果当前图片处于放大状态，禁止下滑关闭
        guard !currentImageView.isZoomed else {
            gesture.state = .cancelled
            return
        }
        
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            initialTouchPoint = gesture.location(in: view)
            isDraggingToDismiss = true
            
        case .changed:
            guard isDraggingToDismiss else { return }
            
            // 只允许向下拖动
            if translation.y > 0 {
                dismissProgress = min(translation.y / view.bounds.height, 1.0)
                
                // 移动和缩放效果
                let scale = 1 - (dismissProgress * 0.3)
                let transform = CGAffineTransform(translationX: translation.x * 0.5, y: translation.y)
                    .scaledBy(x: scale, y: scale)
                
                scrollView.transform = transform
                view.backgroundColor = UIColor.white.withAlphaComponent(1 - dismissProgress)
            }
            
        case .ended, .cancelled:
            guard isDraggingToDismiss else { return }
            
            // 判断是否关闭
            let shouldDismiss = dismissProgress > 0.25 || velocity.y > 500
            
            if shouldDismiss {
                dismissBrowser()
            } else {
                resetBrowserPosition()
            }
            
        default:
            break
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let currentImageView = imageViews[currentIndex]
        let location = gesture.location(in: currentImageView)
        
        // 双击切换：如果已放大则恢复，否则放大到指定比例
        if currentImageView.isZoomed {
            currentImageView.setZoomScale(1.0, animated: true)
        } else {
            // 放大到 2 倍，以点击位置为中心
            let rect = CGRect(
                x: location.x - (currentImageView.bounds.width / 4),
                y: location.y - (currentImageView.bounds.height / 4),
                width: currentImageView.bounds.width / 2,
                height: currentImageView.bounds.height / 2
            )
            currentImageView.zoom(to: rect, animated: true)
        }
    }
    
    private func resetBrowserPosition() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.scrollView.transform = .identity
            self.view.backgroundColor = .white
        }, completion: { _ in
            self.isDraggingToDismiss = false
            self.dismissProgress = 0
        })
    }
    
    private func dismissBrowser() {
        UIView.animate(withDuration: 0.25, animations: {
            self.scrollView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            self.view.backgroundColor = .clear
        }, completion: { _ in
            self.dismiss(animated: false, completion: nil)
        })
    }
    
    // MARK: 辅助方法
    private func scrollToIndex(_ index: Int, animated: Bool) {
        let offset = CGPoint(x: view.bounds.width * CGFloat(index), y: 0)
        scrollView.setContentOffset(offset, animated: animated)
    }
}

// MARK: - UIScrollViewDelegate
extension CMImageBrowserViewController: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isDraggingToDismiss else { return }
        
        let width = view.bounds.width
        let offsetX = scrollView.contentOffset.x
        let page = Int(round(offsetX / width))
        
        if page != currentIndex && page >= 0 && page < images.count {
            // 重置之前图片的缩放状态
            imageViews[currentIndex].setZoomScale(1.0, animated: false)
            
            currentIndex = page
            pageControl.currentPage = page
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 如果当前图片已放大，禁止滚动切换
        let currentImageView = imageViews[currentIndex]
        if currentImageView.isZoomed {
            scrollView.isScrollEnabled = false
        } else {
            scrollView.isScrollEnabled = true
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 恢复滚动能力
        scrollView.isScrollEnabled = true
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CMImageBrowserViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            let currentImageView = imageViews[currentIndex]
            
            // 放大状态下不响应下滑手势
            guard !currentImageView.isZoomed else { return false }
            
            let velocity = panGesture.velocity(in: view)
            // 只允许垂直方向的拖动，且向下
            return abs(velocity.y) > abs(velocity.x) && velocity.y > 0
        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许手势共存
        return true
    }
}

// MARK: - ZoomableImageViewDelegate
extension CMImageBrowserViewController: CMZoomableImageViewDelegate {
    
    func zoomableImageViewDidZoom(_ imageView: CMZoomableImageView) {
        // 缩放时更新 ScrollView 的滚动状态
        scrollView.isScrollEnabled = !imageView.isZoomed
    }
}


class ExampleViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let button = UIButton(type: .system)
        button.setTitle("打开图片浏览器", for: .normal)
        button.addTarget(self, action: #selector(openBrowser), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func openBrowser() {
        // 示例图片
        let images: [UIImage] = [
            UIImage(systemName: "photo.fill")!,
            UIImage(systemName: "photo.on.rectangle.fill")!,
            UIImage(systemName: "photo.stack.fill")!
        ]
        
        let browser = CMImageBrowserViewController(images: images, initialIndex: 0)
        present(browser, animated: true, completion: nil)
    }
}

struct VV: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ExampleViewController {
        let vc = ExampleViewController()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ExampleViewController, context: Context) {
        
    }
}

import SwiftUI
#Preview {
    VV()
//    Image(uiImage: UIImage(systemName: "photo.fill")!)
}
