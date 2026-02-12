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
    var body: some Scene {
        WindowGroup {
            CMCameraPreviewDemo()
                .ignoresSafeArea()
        }
    }
}
