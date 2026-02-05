//
//  CometDemoApp.swift
//  CometDemo
//
//  Created by zhuangxiaowei on 2026/2/4.
//

import SwiftUI
import Camera

@main
struct CometDemoApp: App {
    @ObservedObject var camera = CMCamera()
    var body: some Scene {
        WindowGroup {
            CMCameraView_SwifUI(camera: camera)
                .task {
                    camera.start()
                }
        }
    }
}
