//
//  CometDemoApp.swift
//  CometDemo
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI
import Camera
import Asset

@main
struct CometDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CMCameraPreviewDemo()
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Camera", systemImage: "camera")
                    }

                CMPhotoEditorDemo()
                    .tabItem {
                        Label("PhotoEditor", systemImage: "slider.horizontal.3")
                    }
                
                AssetDemoView()
                    .tabItem {
                        Label("Asset", systemImage: "photo.on.rectangle.angled")
                    }
            }
        }
    }
}

/// Asset功能Demo视图
struct AssetDemoView: View {
    /// 是否显示相册选择器
    @State private var showAssetPicker: Bool = false
    /// 选中的图片列表
    @State private var selectedAssets: [CMAsset] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("相册访问功能")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 40)
            
            Text("点击下方按钮打开相册选择器")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            // 相册访问按钮
            Button(action: { showAssetPicker = true }) {
                Label("打开相册", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
            
            // 显示选中的图片数量
            if !selectedAssets.isEmpty {
                VStack {
                    Text("已选择 \(selectedAssets.count) 张图片")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    ForEach(selectedAssets) { asset in
                        Text("• \(asset.id.prefix(8))...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
            }
        }
        .padding()
        .assetPicker(
            isPresented: $showAssetPicker,
            selectedAssets: $selectedAssets,
            allowsMultipleSelection: true
        )
    }
}