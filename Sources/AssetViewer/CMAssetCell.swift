//
//  CMAssetCell.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Photos
import Combine

public struct CMAssetCell: View {
    let asset: CMAsset
    let size: CGSize
    let isSelected: Bool
    let selectionNumber: Int?
    let onTap: () -> Void
    let onSelectionToggle: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var showCloudIcon: Bool = false
    
    private let imageCache = CMImageCache.shared
    @State private var imageLoadCancellable: AnyCancellable?
    
    public init(
        asset: CMAsset,
        size: CGSize,
        isSelected: Bool = false,
        selectionNumber: Int? = nil,
        onTap: @escaping () -> Void = {},
        onSelectionToggle: @escaping () -> Void = {}
    ) {
        self.asset = asset
        self.size = size
        self.isSelected = isSelected
        self.selectionNumber = selectionNumber
        self.onTap = onTap
        self.onSelectionToggle = onSelectionToggle
    }
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    thumbnailView
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
            
            selectionIndicator
            
            if showCloudIcon {
                cloudIconOverlay
            }
            
            if isLoading {
                loadingIndicator
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            loadThumbnail()
        }
        .onTapGesture {
            onTap()
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let image = thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .transition(.opacity)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        Button(action: onSelectionToggle) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                if isSelected, let number = selectionNumber {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var cloudIconOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                CMCloudIconView(
                    asset: asset.asset,
                    isPresented: $showCloudIcon,
                    iconSize: 24
                )
                .padding(8)
            }
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        ProgressView()
            .scaleEffect(0.8)
            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
    }
    
    private func loadThumbnail() {
        isLoading = true
        
        imageLoadCancellable = imageCache.loadImage(for: asset.asset, size: size)
            .sink { state in
                
                switch state {
                    case .loading:
                        break
                    case .loaded(let image):
                        self.thumbnailImage = image
                        self.isLoading = false
                        self.checkCloudStatus()
                    case .failed:
                        self.isLoading = false
                    case .idle:
                        break
                }
            }
    }
    
    private func checkCloudStatus() {
        guard !isLoading else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let inCloud = CMCloudIconView.shouldShowCloudIcon(for: asset.asset)
            
            DispatchQueue.main.async {
                self.showCloudIcon = inCloud
            }
        }
    }
}



public extension CMAssetCell {
    static func placeholder(size: CGSize) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: size.width, height: size.height)
            .cornerRadius(8)
    }
}

struct CMAssetCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            CMAssetCell(
                asset: CMAsset(asset: PHAsset()),
                size: CGSize(width: 100, height: 100),
                isSelected: false
            )
            
            CMAssetCell(
                asset: CMAsset(asset: PHAsset()),
                size: CGSize(width: 100, height: 100),
                isSelected: true,
                selectionNumber: 1
            )
        }
        .padding()
    }
}
