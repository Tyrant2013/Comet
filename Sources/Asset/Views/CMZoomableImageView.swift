//
//  File.swift
//  Comet
//

import Foundation
import UIKit

struct CMBrowserConfiguration {
    var maxZoomScale: CGFloat = 3.0
    var minZoomScale: CGFloat = 1.0
    var doubleTapZoomScale: CGFloat = 2.0
    var dismissThreshold: CGFloat = 0.25
    var dismissVelocityThreshold: CGFloat = 500
}

class CMZoomableImageView: UIScrollView {
    weak var zoomDelegate: CMZoomableImageViewDelegate?
        
        private let imageView: UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.clipsToBounds = true
            iv.isUserInteractionEnabled = true
            return iv
        }()
        
        var isZoomed: Bool {
            return zoomScale > 1.01
        }
        
        var image: UIImage? {
            get { return imageView.image }
            set {
                imageView.image = newValue
                setupImageView()
            }
        }
        
        init(image: UIImage?) {
            super.init(frame: .zero)
            self.image = image
            setupUI()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupUI() {
            delegate = self
            showsHorizontalScrollIndicator = false
            showsVerticalScrollIndicator = false
            decelerationRate = .fast
            alwaysBounceVertical = false
            alwaysBounceHorizontal = false
            
            addSubview(imageView)
            
            // 双击手势
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTap)
        }
        
        private func setupImageView() {
            guard let image = imageView.image else { return }
            
            // 计算适合屏幕的缩放比例
            let screenSize = UIScreen.main.bounds.size
            let imageSize = image.size
            
            let widthScale = screenSize.width / imageSize.width
            let heightScale = screenSize.height / imageSize.height
            
            let minScale = min(widthScale, heightScale)
            let maxScale = max(3.0, minScale * 3)
            
            minimumZoomScale = minScale
            maximumZoomScale = maxScale
            zoomScale = minScale
            
            // 居中显示
            centerImageView()
        }
        
        private func centerImageView() {
            let boundsSize = bounds.size
            var frameToCenter = imageView.frame
            frameToCenter.size = image?.size ?? .zero
            
            // 水平居中
            if frameToCenter.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            // 垂直居中
            if frameToCenter.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            imageView.frame = frameToCenter
            print("Image:", frameToCenter, image?.size as Any)
        }
        
        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: imageView)
            
            if isZoomed {
                setZoomScale(minimumZoomScale, animated: true)
            } else {
                // 放大 2 倍
                let newScale = min(maximumZoomScale, minimumZoomScale * 2)
                let rect = CGRect(
                    x: location.x - (bounds.width / newScale) / 2,
                    y: location.y - (bounds.height / newScale) / 2,
                    width: bounds.width / newScale,
                    height: bounds.height / newScale
                )
                zoom(to: rect, animated: true)
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            centerImageView()
        }
}

// MARK: - UIScrollViewDelegate
extension CMZoomableImageView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
        zoomDelegate?.zoomableImageViewDidZoom(self)
    }
}

// MARK: - 代理协议
protocol CMZoomableImageViewDelegate: AnyObject {
    func zoomableImageViewDidZoom(_ imageView: CMZoomableImageView)
}
