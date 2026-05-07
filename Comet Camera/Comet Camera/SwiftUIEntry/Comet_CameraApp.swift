//
//  Comet_CameraApp.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI
import CoreData
import Asset

struct Comet_CameraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            // This is kept for preview purposes only
            // Actual launch is handled by UIKit (AppDelegate/SceneDelegate)
            EmptyView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
