//
//  CMCameraPreviewDemo.swift
//  CameraExample
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI

struct CMCameraPreviewDemo: View {
    @ObservedObject var camera: CMCamera = CMCamera()
    var body: some View {
        CMCameraView_SwifUI(camera: camera)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .task {
                camera.start()
            }
    }
}

#Preview {
    CMCameraPreviewDemo()
}
