//
//  CMAssetPreviewViewModel.swift
//  Comet
//

import Foundation
import Combine

final class CMAssetPreviewViewModel: ObservableObject {
    /// 预览的图片索引
    @Published var previewIndex: Int = 0
    /// 是否显示编辑视图
    @Published var showEditView = false
}
