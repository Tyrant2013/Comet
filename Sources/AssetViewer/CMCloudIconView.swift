//
//  CMCloudIconView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Photos
import Combine

public enum CMCloudDownloadState {
    case idle
    case downloading(progress: Double)
    case completed
    case failed(Error)
}

public final class CMCloudDownloadManager: ObservableObject {
    @Published public var downloadState: CMCloudDownloadState = .idle
    @Published public var downloadProgress: Double = 0.0
    
    private let imageManager = PHImageManager.default()
    private var currentRequestID: PHImageRequestID?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    public func downloadImage(from asset: PHAsset) {
        guard currentRequestID == nil else { return }
        
        downloadState = .downloading(progress: 0.0)
        downloadProgress = 0.0
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.progressHandler = { [weak self] progress, _, _, _ in
            DispatchQueue.main.async {
                self?.downloadProgress = Double(progress)
                self?.downloadState = .downloading(progress: Double(progress))
            }
        }
        
        let requestID = imageManager.requestImageData(for: asset, options: options) { [weak self] data, _, _, info in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = info?[PHImageErrorKey] as? Error {
                    self.downloadState = .failed(error)
                    self.currentRequestID = nil
                    return
                }
                
                if data != nil {
                    self.downloadState = .completed
                } else {
                    self.downloadState = .idle
                }
                
                self.currentRequestID = nil
            }
        }
        
        currentRequestID = requestID
    }
    
    public func cancelDownload() {
        if let requestID = currentRequestID {
            imageManager.cancelImageRequest(requestID)
            currentRequestID = nil
        }
        downloadState = .idle
        downloadProgress = 0.0
    }
    
    public func reset() {
        cancelDownload()
        downloadState = .idle
        downloadProgress = 0.0
    }
}

public struct CMCloudIconView: View {
    @ObservedObject private var downloadManager: CMCloudDownloadManager
    @Binding private var isPresented: Bool
    private let asset: PHAsset
    private let iconSize: CGFloat
    private let onDownloadComplete: (() -> Void)?
    
    public init(
        asset: PHAsset,
        isPresented: Binding<Bool>,
        iconSize: CGFloat = 40,
        onDownloadComplete: (() -> Void)? = nil
    ) {
        self.asset = asset
        self._isPresented = isPresented
        self.iconSize = iconSize
        self.onDownloadComplete = onDownloadComplete
        self.downloadManager = CMCloudDownloadManager()
    }
    
    public var body: some View {
        ZStack {
            if isPresented {
                cloudIconView
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
    
    @ViewBuilder
    private var cloudIconView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                switch downloadManager.downloadState {
                case .idle:
                    idleIcon
                case .downloading(let progress):
                    downloadingIcon(progress: progress)
                case .completed:
                    completedIcon
                case .failed:
                    failedIcon
                }
            }
            .onTapGesture {
                handleTap()
            }
            
            if case .downloading(let progress) = downloadManager.downloadState {
                progressView(progress: progress)
            }
        }
    }
    
    private var idleIcon: some View {
        Image(systemName: "icloud")
            .font(.system(size: iconSize * 0.5))
            .foregroundColor(.blue)
    }
    
    private func downloadingIcon(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                .frame(width: iconSize * 0.6, height: iconSize * 0.6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: iconSize * 0.6, height: iconSize * 0.6)
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: progress)
            
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: iconSize * 0.3))
                .foregroundColor(.blue)
        }
    }
    
    private var completedIcon: some View {
        Image(systemName: "icloud.fill")
            .font(.system(size: iconSize * 0.5))
            .foregroundColor(.green)
    }
    
    private var failedIcon: some View {
        Image(systemName: "icloud.slash")
            .font(.system(size: iconSize * 0.5))
            .foregroundColor(.red)
    }
    
    private func progressView(progress: Double) -> some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: iconSize * 1.5)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    private func handleTap() {
        switch downloadManager.downloadState {
        case .idle:
            downloadManager.downloadImage(from: asset)
        case .downloading:
            downloadManager.cancelDownload()
        case .completed:
            onDownloadComplete?()
        case .failed:
            downloadManager.downloadImage(from: asset)
        }
    }
}

public extension CMCloudIconView {
    static func shouldShowCloudIcon(for asset: PHAsset) -> Bool {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat
        
        var isInCloud = false
        let semaphore = DispatchSemaphore(value: 0)
        
        let targetSize = CGSize(width: 1, height: 1)
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { _, info in
            if let inCloud = info?[PHImageResultIsInCloudKey] as? Bool {
                isInCloud = inCloud
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return isInCloud
    }
}

public extension View {
    func cloudIconOverlay(
        asset: PHAsset,
        showCloudIcon: Bool,
        iconSize: CGFloat = 40,
        onDownloadComplete: (() -> Void)? = nil
    ) -> some View {
        self.overlay(
            Group {
                if showCloudIcon {
                    CMCloudIconView(
                        asset: asset,
                        isPresented: .constant(true),
                        iconSize: iconSize,
                        onDownloadComplete: onDownloadComplete
                    )
                }
            }
        )
    }
}

public struct CMCloudAssetView<Content: View>: View {
    let asset: PHAsset
    let content: Content
    let iconSize: CGFloat
    let onDownloadComplete: (() -> Void)?
    
    @State private var showCloudIcon: Bool = false
    @State private var isLoading: Bool = true
    
    public init(
        asset: PHAsset,
        iconSize: CGFloat = 40,
        onDownloadComplete: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.asset = asset
        self.iconSize = iconSize
        self.onDownloadComplete = onDownloadComplete
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            content
            
            if showCloudIcon {
                CMCloudIconView(
                    asset: asset,
                    isPresented: $showCloudIcon,
                    iconSize: iconSize,
                    onDownloadComplete: onDownloadComplete
                )
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .onAppear {
            checkCloudStatus()
        }
    }
    
    private func checkCloudStatus() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let inCloud = CMCloudIconView.shouldShowCloudIcon(for: asset)
            
            DispatchQueue.main.async {
                self.showCloudIcon = inCloud
                self.isLoading = false
            }
        }
    }
}
