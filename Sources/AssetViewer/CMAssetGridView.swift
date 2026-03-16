//
//  CMAssetGridView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI
import Combine

public struct CMAssetGridView: View {
    @ObservedObject private var viewModel: CMAssetGridViewModel
    @State private var selectedAssets: Set<String> = []
    @State private var isSelectionMode: Bool = false
    
    private let columns: [GridItem]
    private let cellSpacing: CGFloat
    private let onAssetTap: (CMAsset) -> Void
    private let onSelectionChanged: ([CMAsset]) -> Void
    
    public init(
        assets: [CMAsset],
        columns: Int = 3,
        cellSpacing: CGFloat = 2,
        onAssetTap: @escaping (CMAsset) -> Void = { _ in },
        onSelectionChanged: @escaping ([CMAsset]) -> Void = { _ in }
    ) {
        self.viewModel = CMAssetGridViewModel(assets: assets)
        self.columns = Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columns)
        self.cellSpacing = cellSpacing
        self.onAssetTap = onAssetTap
        self.onSelectionChanged = onSelectionChanged
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.assets.isEmpty {
                emptyView
            } else {
                gridView
            }
        }
        .onAppear {
            viewModel.loadAssets()
        }
    }
    
    @ViewBuilder
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: cellSpacing) {
                ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
                    CMAssetCell(
                        asset: asset,
                        size: calculateCellSize(),
                        isSelected: selectedAssets.contains(asset.id),
                        selectionNumber: selectionNumber(for: asset.id),
                        onTap: {
                            handleAssetTap(asset)
                        },
                        onSelectionToggle: {
                            toggleSelection(for: asset)
                        }
                    )
                    .onAppear {
                        handleCellAppear(at: index)
                    }
                }
            }
            .padding(cellSpacing)
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载中...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("暂无图片")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private func calculateCellSize() -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let totalSpacing = CGFloat(columns.count - 1) * cellSpacing + (cellSpacing * 2)
        let availableWidth = screenWidth - totalSpacing
        let cellWidth = availableWidth / CGFloat(columns.count)
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    private func handleAssetTap(_ asset: CMAsset) {
        if isSelectionMode {
            toggleSelection(for: asset)
        } else {
            onAssetTap(asset)
        }
    }
    
    private func toggleSelection(for asset: CMAsset) {
        if selectedAssets.contains(asset.id) {
            selectedAssets.remove(asset.id)
        } else {
            selectedAssets.insert(asset.id)
        }
        
        isSelectionMode = !selectedAssets.isEmpty
        notifySelectionChanged()
    }
    
    private func selectionNumber(for assetId: String) -> Int? {
        guard selectedAssets.contains(assetId) else { return nil }
        return Array(selectedAssets).firstIndex(of: assetId).map { $0 + 1 }
    }
    
    private func notifySelectionChanged() {
        let selected = viewModel.assets.filter { selectedAssets.contains($0.id) }
        onSelectionChanged(selected)
    }
    
    private func handleCellAppear(at index: Int) {
        viewModel.handleCellAppear(at: index)
    }
    
    public func updateAssets(_ assets: [CMAsset]) {
        viewModel.updateAssets(assets)
    }
    
    public func clearSelection() {
        selectedAssets.removeAll()
        isSelectionMode = false
        notifySelectionChanged()
    }
}

public final class CMAssetGridViewModel: ObservableObject {
    @Published public var assets: [CMAsset] = []
    @Published public var isLoading: Bool = false
    
    private var allAssets: [CMAsset] = []
    private var loadedCount: Int = 0
    private let batchSize: Int = 50
    private var cancellables = Set<AnyCancellable>()
    
    public init(assets: [CMAsset] = []) {
        self.allAssets = assets
    }
    
    public func loadAssets() {
        guard !isLoading else { return }
        
        isLoading = true
        loadedCount = 0
        assets = []
        
        loadNextBatch()
    }
    
    private func loadNextBatch() {
        guard loadedCount < allAssets.count else {
            isLoading = false
            return
        }
        
        let endIndex = min(loadedCount + batchSize, allAssets.count)
        let batch = Array(allAssets[loadedCount..<endIndex])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.assets.append(contentsOf: batch)
            self.loadedCount = endIndex
            self.isLoading = false
        }
    }
    
    public func handleCellAppear(at index: Int) {
        let threshold = assets.count - 10
        
        if index >= threshold && loadedCount < allAssets.count {
            loadNextBatch()
        }
    }
    
    public func updateAssets(_ newAssets: [CMAsset]) {
        allAssets = newAssets
        loadAssets()
    }
    
    public func appendAssets(_ newAssets: [CMAsset]) {
        allAssets.append(contentsOf: newAssets)
    }
}

public extension CMAssetGridView {
    func selectionMode(_ isEnabled: Bool) -> some View {
        self.environment(\.selectionMode, isEnabled)
    }
}

private struct SelectionModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {
    var selectionMode: Bool {
        get { self[SelectionModeKey.self] }
        set { self[SelectionModeKey.self] = newValue }
    }
}

struct CMAssetGridView_Previews: PreviewProvider {
    static var previews: some View {
        CMAssetGridView(
            assets: [],
            columns: 3
        )
    }
}
