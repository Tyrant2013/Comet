//
//  Comet_CameraApp.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI
import CoreData
import Asset

@main
struct Comet_CameraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            CMAssetPickerView()
//            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
