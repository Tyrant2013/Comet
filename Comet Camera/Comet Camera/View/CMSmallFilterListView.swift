//
//  CMSmallFilterListView.swift
//  Comet Camera
//
//  Created by 桃园谷 on 2026/3/25.
//

import SwiftUI
import UIKit

struct CMSmallFilterListView: View {
    let image: UIImage
    var body: some View {
        GeometryReader { geometry in
            
            CMScrollView(itemSize: image.size) {
                HStack(spacing: 4) {
                    ForEach(0..<10) { index in
                        Image(uiImage: image)
                            .frame(width: image.size.width, height: image.size.height)
                            .clipShape(.rect(cornerRadius: 5))
                            .id(index)
                            .overlay(
                                Rectangle()
                                    .frame(width: 1)
                                    .foregroundStyle(Color.yellow)
                            )
                        
                    }
                }
                .padding(.horizontal, geometry.size.width / 2 - image.size.width / 2)
            }
            .frame(height: 40)
                
        }
        .frame(height: 40)
        .frame(height: 60)
        .overlay(
            VStack {
                Image(systemName: "triangle.fill")
                    .rotationEffect(.degrees(180))
                Spacer()
                Image(systemName: "triangle.fill")
            }
                .font(.system(size: 10))
        )
        .onAppear {
            print("C:", image.size)
        }
    }
}

#Preview {
    CMSmallFilterListView(image: UIImage(named: "PreviewImage")!.preparingThumbnail(of: .init(width: 30, height: 40))!)
}

struct CMScrollView<Content: View>: UIViewRepresentable {
    let itemSize: CGSize
    let content: () -> Content
    func makeUIView(context: Context) -> UIScrollView {
        let vv = UIScrollView()
        vv.showsVerticalScrollIndicator = false
        vv.showsHorizontalScrollIndicator = false
        vv.isScrollEnabled = true
        let contentView = UIHostingController(rootView: content()).view!
        vv.addSubview(contentView)
        vv.delegate = context.coordinator
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: vv.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: vv.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: vv.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: vv.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: vv.heightAnchor),
        ])
        return vv
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: CMScrollView
        var index: Int = 0
        init(parent: CMScrollView) {
            self.parent = parent
        }
        
//        func scrollViewDidScroll(_ scrollView: UIScrollView) {
//            let x = scrollView.contentOffset.x
//            let index = Int(x / parent.itemSize.width)
//            guard self.index != index else { return }
//            self.index = index
//        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            
            let targetIndex = Int(targetContentOffset.pointee.x / (parent.itemSize.width + 4))
            let targetOffsetX = CGFloat(targetIndex) * (parent.itemSize.width + 4)
            targetContentOffset.pointee.x = targetOffsetX
        }
    }
}

extension UIImage {
    
    /// 生成指定大小的缩略图（保持宽高比，居中裁剪）
    /// - Parameters:
    ///   - targetSize: 目标尺寸
    ///   - mode: 缩放模式
    ///   - quality: 插值质量
    /// - Returns: 缩略图
    func thumbnail(
        ofSize targetSize: CGSize,
        mode: ContentMode = .aspectFill,
        quality: CGInterpolationQuality = .default
    ) -> UIImage? {
        
        let scale = UIScreen.main.scale
        let scaledSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
        
        let rect: CGRect
        
        switch mode {
        case .scaleToFill:
            // 拉伸填充，可能变形
            rect = CGRect(origin: .zero, size: scaledSize)
            
        case .aspectFit:
            // 完整显示，可能有留白
            let widthRatio = scaledSize.width / size.width
            let heightRatio = scaledSize.height / size.height
            let ratio = min(widthRatio, heightRatio)
            
            let newSize = CGSize(
                width: size.width * ratio,
                height: size.height * ratio
            )
            let x = (scaledSize.width - newSize.width) / 2
            let y = (scaledSize.height - newSize.height) / 2
            rect = CGRect(origin: CGPoint(x: x, y: y), size: newSize)
            
        case .aspectFill:
            // 裁剪填充，填满目标尺寸
            let widthRatio = scaledSize.width / size.width
            let heightRatio = scaledSize.height / size.height
            let ratio = max(widthRatio, heightRatio)
            
            let newSize = CGSize(
                width: size.width * ratio,
                height: size.height * ratio
            )
            let x = (scaledSize.width - newSize.width) / 2
            let y = (scaledSize.height - newSize.height) / 2
            rect = CGRect(origin: CGPoint(x: x, y: y), size: newSize)
        }
        
        // 使用 UIGraphicsImageRenderer 获得更好的性能
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // 我们已经手动处理了 scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize, format: format)
        
        let thumbnail = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.interpolationQuality = quality
            
            // 处理图片方向
            cgContext.translateBy(x: 0, y: scaledSize.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            
            cgContext.draw(
                self.cgImage!,
                in: rect
            )
        }
        
        return thumbnail
    }
    
    /// 快速生成方形缩略图
    /// - Parameter sideLength: 边长
    /// - Returns: 方形缩略图
    func squareThumbnail(sideLength: CGFloat) -> UIImage? {
        return thumbnail(
            ofSize: CGSize(width: sideLength, height: sideLength),
            mode: .aspectFill
        )
    }
    
    /// 按宽度等比缩放
    /// - Parameter width: 目标宽度
    /// - Returns: 缩放后的图片
    func scaled(toWidth width: CGFloat) -> UIImage? {
        let ratio = width / size.width
        let height = size.height * ratio
        return thumbnail(
            ofSize: CGSize(width: width, height: height),
            mode: .scaleToFill
        )
    }
    
    /// 按高度等比缩放
    /// - Parameter height: 目标高度
    /// - Returns: 缩放后的图片
    func scaled(toHeight height: CGFloat) -> UIImage? {
        let ratio = height / size.height
        let width = size.width * ratio
        return thumbnail(
            ofSize: CGSize(width: width, height: height),
            mode: .scaleToFill
        )
    }
    
    // MARK: - 枚举定义
    
    enum ContentMode {
        case scaleToFill      // 拉伸填充
        case aspectFit        // 适应（完整显示）
        case aspectFill       // 填充（裁剪）
    }
}
