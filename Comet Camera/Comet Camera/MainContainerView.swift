//
//  MainContainerView.swift
//  Comet Camera
//

import SwiftUI
import Asset
import Camera

struct MainContainerView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showSavedPhotos = false
    
    var body: some View {
        ZStack {
            Group {
                switch settingsManager.startupPage {
                case .camera:
                    CameraMainView()
                case .album:
                    CMAssetPickerView()
                }
            }
            
            // 浮动按钮 - 查看已保存的照片
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showSavedPhotos = true
                    }) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .fullScreenCover(isPresented: $showSavedPhotos) {
            SavedPhotosView()
        }
    }
}

#Preview {
    MainContainerView()
}
