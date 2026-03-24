//
//  CMImageBrowserCell.swift
//  Comet
//

import UIKit

// MARK: - 图片浏览器 Cell（复用单元）
class CMImageBrowserCell: UICollectionViewCell {
    
    static let identifier = "CMImageBrowserCell"
    
    weak var zoomDelegate: CMImageBrowserCellDelegate?
    
    // MARK: UI 组件
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.delegate = self
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.maximumZoomScale = 3.0
        sv.minimumZoomScale = 1.0
        sv.decelerationRate = .fast
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // MARK: 属性
    var isZoomed: Bool {
        return scrollView.zoomScale > 1.01
    }
    
    // MARK: 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // 复用时重置状态
        resetZoom()
        imageView.image = nil
    }
    
    // MARK: 设置 UI
    private func setupUI() {
        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    // MARK: 配置
    func configure(with image: UIImage) {
        imageView.image = image
    }
    
    func confige(with asset: CMAsset) {
        imageView.image = asset.image
    }
    
    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: false)
    }
    
    func handleDoubleTap(at point: CGPoint) {
        if isZoomed {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            // 放大 2 倍，以点击位置为中心
            let newScale = min(scrollView.maximumZoomScale, 2.0)
            let rect = CGRect(
                x: point.x - (bounds.width / newScale) / 2,
                y: point.y - (bounds.height / newScale) / 2,
                width: bounds.width / newScale,
                height: bounds.height / newScale
            )
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension CMImageBrowserCell: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 居中显示
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        
        zoomDelegate?.CMImageBrowserCellDidZoom(self)
    }
}
