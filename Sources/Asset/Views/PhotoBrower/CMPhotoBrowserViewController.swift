//
//  EfficientImageBrowserViewController.swift
//  Comet
//

import UIKit
import Photos

protocol CMDatasourceProtocol: UICollectionViewDataSource {
    var count: Int { get }
    var collectionView: UICollectionView? { get set }
}

// MARK: - 图片浏览器控制器（基于 UICollectionView 复用）
public class CMPhotoBrowserViewController: UIViewController {
    
    private var currentIndex: Int
    private var isFirstLayout = true
    
    // MARK: UI 组件
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
            
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.backgroundColor = .white
        cv.delegate = self
        cv.dataSource = self.dataSource
        cv.register(CMImageBrowserCell.self, forCellWithReuseIdentifier: CMImageBrowserCell.identifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()
    
    private let dataSource: any CMDatasourceProtocol
    
    // MARK: 手势
    private var panGesture: UIPanGestureRecognizer!
    private var isDraggingToDismiss = false
    private var dismissProgress: CGFloat = 0
    
    // MARK: 状态
    private var currentCell: CMImageBrowserCell? {
        let indexPath = IndexPath(item: currentIndex, section: 0)
        return collectionView.cellForItem(at: indexPath) as? CMImageBrowserCell
    }
    
    // MARK: 初始化
    init(dataSource: any CMDatasourceProtocol, initialIndex: Int = 0) {
        self.currentIndex = initialIndex
        self.dataSource = dataSource
        
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
        
        print("CMPhotoBrowser Count:", dataSource.count)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: 生命周期
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 设置 itemSize 为屏幕大小
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = view.bounds.size
        }
        
        // 首次布局时滚动到初始位置
        if isFirstLayout && dataSource.count > currentIndex {
            isFirstLayout = false
            let indexPath = IndexPath(item: currentIndex, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        }
    }
    
    // MARK: 设置 UI
    private func setupUI() {
        view.backgroundColor = .black
        dataSource.collectionView = collectionView
        
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        guard let cell = currentCell else { return }
        
        // 放大状态下禁止下滑关闭
        guard !cell.isZoomed else {
            gesture.state = .cancelled
            return
        }
        
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .began:
            isDraggingToDismiss = true
            
        case .changed:
            guard isDraggingToDismiss, translation.y > 0 else { return }
            
            dismissProgress = min(translation.y / view.bounds.height, 1.0)
            
            let scale = 1 - (dismissProgress * 0.3)
            let transform = CGAffineTransform(translationX: translation.x * 0.3, y: translation.y)
                .scaledBy(x: scale, y: scale)
            
            collectionView.transform = transform
            collectionView.layer.cornerRadius = 20 * scale
            view.backgroundColor = UIColor.black.withAlphaComponent(1 - dismissProgress)
            
        case .ended, .cancelled:
            guard isDraggingToDismiss else { return }
            
            let velocity = gesture.velocity(in: view)
            let shouldDismiss = dismissProgress > 0.25 || velocity.y > 500
            
            if shouldDismiss {
                dismissBrowser()
            } else {
                resetPosition()
            }
            
        default:
            break
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let cell = currentCell else { return }
        let location = gesture.location(in: cell)
        cell.handleDoubleTap(at: location)
    }
    
    private func resetPosition() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.collectionView.transform = .identity
            self.view.backgroundColor = .black
            self.collectionView.layer.cornerRadius = 0
        }) { _ in
            self.isDraggingToDismiss = false
            self.dismissProgress = 0
        }
    }
    
    private func dismissBrowser() {
        UIView.animate(withDuration: 0.25, animations: {
            self.collectionView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
            self.view.backgroundColor = .clear
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }
}

// MARK: - UICollectionViewDelegate
extension CMPhotoBrowserViewController: UICollectionViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isDraggingToDismiss else { return }
        
        let width = view.bounds.width
        let offsetX = scrollView.contentOffset.x + width / 2
        let page = Int(offsetX / width)
        
        if page != currentIndex && page >= 0 && page < dataSource.count {
            // 重置之前 Cell 的缩放状态
            if let previousCell = collectionView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? CMImageBrowserCell {
                previousCell.resetZoom()
            }
            
            currentIndex = page
        }
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 如果当前 Cell 已放大，禁止滚动切换
        guard let cell = currentCell else { return }
        collectionView.isScrollEnabled = !cell.isZoomed
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        collectionView.isScrollEnabled = true
    }
}

// MARK: - UIGestureRecognizerDelegate
extension CMPhotoBrowserViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            guard let cell = currentCell, !cell.isZoomed else { return false }
            
            let velocity = panGesture.velocity(in: view)
            return abs(velocity.y) > abs(velocity.x) && velocity.y > 0
        }
        return true
    }
}

// MARK: - CMImageBrowserCellDelegate
//extension CMPhotoBrowserViewController: CMImageBrowserCellDelegate {
//    
//    func CMImageBrowserCellDidZoom(_ cell: CMImageBrowserCell) {
//        collectionView.isScrollEnabled = !cell.isZoomed
//    }
//}

// MARK: - 使用示例
class ExampleViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let button = UIButton(type: .system)
        button.setTitle("打开图片浏览器（10000张图片）", for: .normal)
        button.addTarget(self, action: #selector(openBrowser), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func openBrowser() {
        // 模拟 10000 张图片
        var images: [UIImage] = []
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple]
        
        for i in 0..<10 {
            let color = colors[i % colors.count]
            let image = createImage(color: color, text: "\(i + 1)")
            images.append(image)
        }
        
        let browser = CMPhotoBrowserViewController(dataSource: ImageDataSource(), initialIndex: 0)
        present(browser, animated: true, completion: nil)
    }
    
    private func createImage(color: UIColor, text: String) -> UIImage {
        let size = CGSize(width: 1920, height: 1080)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 200, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let string = text as NSString
        let textSize = string.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        string.draw(in: textRect, withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}

class ImageDataSource: NSObject, CMDatasourceProtocol {
    var count: Int { images.count }
    
    var collectionView: UICollectionView?
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CMImageBrowserCell.identifier, for: indexPath) as! CMImageBrowserCell
            
        cell.configure(with: images[indexPath.item])
        cell.zoomDelegate = self
        return cell
    }
    
    var images: [UIImage] = []
    
    override init() {
        super.init()
        
        var images: [UIImage] = []
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple]
        
        for i in 0..<10 {
            let color = colors[i % colors.count]
            let image = createImage(color: color, text: "\(i + 1)")
            images.append(image)
        }
        self.images = images
    }
    
    private func createImage(color: UIColor, text: String) -> UIImage {
        let size = CGSize(width: 1920, height: 1080)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 200, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let string = text as NSString
        let textSize = string.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        string.draw(in: textRect, withAttributes: attributes)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
}

extension ImageDataSource: CMImageBrowserCellDelegate {
    func CMImageBrowserCellDidZoom(_ cell: CMImageBrowserCell) {
        collectionView?.isScrollEnabled = !cell.isZoomed
    }
}
