//
//  CMSmallFilterListView.swift
//  Comet Camera
//

import SwiftUI
import UIKit
import PhotoEditor

struct CMSmallFilterListView: View {
    let image: UIImage
    let filters: [CMPhotoEditorFilter] = CMPhotoEditorFilter.allFilters()
    var filterSelected: ((CMPhotoEditorFilter) -> Void)?
    @State private var filterPreviews: [UIImage] = []
    
    var body: some View {
        GeometryReader { geometry in
            
            CMScrollView(itemSize: CGSize(width: 60, height: 60), spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<filters.count, id: \.self) { index in
                        Button(action: {
                            filterSelected?(filters[index])
                        }) {
                            Image(uiImage: filterPreviews.count > index ? filterPreviews[index] : image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(.rect(cornerRadius: 8))
                                .id(index)
                        }
                    }
                }
                .padding(.horizontal, geometry.size.width / 2 - 30)
            }
            .frame(height: 80)
        }
        .frame(height: 80)
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
            updateFilterPreviews(for: image)
        }
    }
    
    func updateFilterPreviews(for image: UIImage) {
        filterPreviews = filters.map { filter in
            return filter.preview(on: image) ?? image
        }
    }
}

struct CMRadioAngleView: View {
    @Binding var index: Int
    var body: some View {
        GeometryReader { geometry in
            CMScrollView(itemSize: .init(width: 1, height: 20), spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<36, id: \.self) { _ in
                        ForEach(0..<10, id: \.self) { index in
                            Rectangle()
                                .frame(width: 1, height: index % 10 == 0 ? 20 : 10)
                                .opacity(index % 5 == 0 ? 1 : 0)
                        }
                    }
                }
                .padding(.horizontal, geometry.size.width / 2)
            } indexDidChanged: { oldIndex, newIndex in
                print("index:", newIndex)
            }
        }
    }
}

#Preview {
//    CMSmallFilterListView(image: UIImage(named: "PreviewImage")!.preparingThumbnail(of: .init(width: 30, height: 40))!)
    CMRadioAngleView(index: .constant(0))
}

struct CMScrollView<Content: View>: UIViewRepresentable {
    let itemSize: CGSize
    var spacing: CGFloat = 0
    @ViewBuilder
    let content: () -> Content
    var indexDidChanged: ((_ oldIndex: Int, _ newIndex: Int) -> Void)?
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.alwaysBounceHorizontal = true
        
        let host = UIHostingController(rootView: content())
        let contentView = host.view!
        contentView.backgroundColor = .clear
        
        scrollView.addSubview(contentView)
        scrollView.delegate = context.coordinator
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: CMScrollView
        var contentView: UIView?
        
        private var lastHapticIndex: Int = -1
        private let feedbackGenerator = UISelectionFeedbackGenerator()
        
        init(parent: CMScrollView) {
            self.parent = parent
            super.init()
            self.feedbackGenerator.prepare()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetX = scrollView.contentOffset.x
            let index = Int(offsetX / (parent.itemSize.width + parent.spacing))
            parent.indexDidChanged?(0, index)
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let pageWidth = parent.itemSize.width + parent.spacing
            let targetX = targetContentOffset.pointee.x
            
            let nearestIndex = round(targetX / pageWidth)
            targetContentOffset.pointee.x = nearestIndex * pageWidth
            
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
