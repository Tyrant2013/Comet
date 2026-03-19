//
//  ContentView.swift
//  CometDemo
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI
import Camera
import Asset

struct ContentView: View {
    /// 是否显示相册选择器
    @State private var showAssetPicker: Bool = false
    /// 选中的图片列表
    @State private var selectedAssets: [CMAsset] = []
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Spacer()
            
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
                Text("已选择 \(selectedAssets.count) 张图片")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 16)
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

#Preview {
    ContentView()
}
