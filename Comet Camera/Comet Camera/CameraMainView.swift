//
//  CameraMainView.swift
//  Comet Camera
//

import SwiftUI
import Camera
import Asset

struct CameraMainView: View {
    @StateObject private var camera = CMCamera()
    @State private var showAssetPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var showPreview = false
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 相机预览
                CMCameraView_SwifUI(camera: camera)
                    .ignoresSafeArea()
                
                VStack {
                    // 顶部工具栏
                    HStack {
                        Button(action: {
                            showAssetPicker = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            _ = camera.switchCamera()
                        }) {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .frame(height: 44)
                    
                    Spacer()
                    
                    // 镜头选择器
                    CCLensBar(lensControl: CCLensControl())
                        .padding(.bottom, 120)
                    
                    // 底部控制区
                    ZStack {
                        // 相册按钮
                        Button(action: {
                            showAssetPicker = true
                        }) {
                            ZStack {
                                Color.orange
                                    .clipShape(.rect(cornerRadius: 8))
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 50, height: 50)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 50)
                        
                        // 拍照按钮
                        Button(action: {
                            capturePhoto()
                        }) {
                            Circle()
                                .foregroundStyle(.white)
                                .padding(5)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                        )
                        
                        // 切换摄像头按钮
                        Button(action: {
                            _ = camera.switchCamera()
                        }) {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 50)
                    }
                    .frame(height: 140, alignment: .top)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .fullScreenCover(isPresented: $showAssetPicker) {
            CMAssetPickerView()
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let image = capturedImage {
                ImagePreviewView(image: image, source: .camera, asset: nil)
            }
        }
    }
    
    private func capturePhoto() {
        Task {
            if let photo = await camera.takePhoto() {
                let uiImage = photo.pixelBuffer.toUIImage()
                await MainActor.run {
                    self.capturedImage = uiImage
                    self.showPreview = true
                }
            }
        }
    }
}

extension CVPixelBuffer {
    func toUIImage() -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    CameraMainView()
}
