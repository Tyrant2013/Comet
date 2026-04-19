//
//  SettingsManager.swift
//  Comet Camera
//

import Foundation
import Combine

enum StartupPage: String, CaseIterable {
    case camera = "camera"
    case album = "album"
    
    var title: String {
        switch self {
        case .camera:
            return "相机"
        case .album:
            return "相册"
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let startupPageKey = "com.cometcamera.startupPage"
    
    @Published var startupPage: StartupPage {
        didSet {
            UserDefaults.standard.set(startupPage.rawValue, forKey: startupPageKey)
        }
    }
    
    private init() {
        let savedValue = UserDefaults.standard.string(forKey: startupPageKey) ?? StartupPage.album.rawValue
        self.startupPage = StartupPage(rawValue: savedValue) ?? .album
    }
    
    func setStartupPage(_ page: StartupPage) {
        self.startupPage = page
    }
}
