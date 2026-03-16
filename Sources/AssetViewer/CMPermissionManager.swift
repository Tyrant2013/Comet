//
//  CMPermissionManager.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import Foundation
import Photos
import Combine
import UIKit

public enum CMPermissionStatus {
    case authorized
    case denied
    case restricted
    case notDetermined
    case limited
    
    public var isAuthorized: Bool {
        switch self {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }
}

public enum CMPermissionError: Error {
    case denied
    case restricted
    case requestFailed
    
    public var errorDescription: String? {
        switch self {
        case .denied:
            return "相册访问权限被拒绝，请在系统设置中开启。"
        case .restricted:
            return "相册访问受限，无法访问相册。"
        case .requestFailed:
            return "请求权限失败。"
        }
    }
}

public final class CMPermissionManager: ObservableObject {
    public static let shared = CMPermissionManager()
    
    @Published public var authorizationStatus: CMPermissionStatus = .notDetermined
    @Published public var isAuthorized: Bool = false
    @Published public var error: CMPermissionError?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthorizationStatus()
        setupObservers()
    }
    
    public func checkAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        updateStatus(status)
    }
    
    public func requestAuthorization(completion: @escaping (Result<Void, CMPermissionError>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.updateStatus(status)
                
                switch status {
                case .authorized, .limited:
                    completion(.success(()))
                case .denied:
                    self?.error = .denied
                    completion(.failure(.denied))
                case .restricted:
                    self?.error = .restricted
                    completion(.failure(.restricted))
                case .notDetermined:
                    completion(.failure(.requestFailed))
                @unknown default:
                    completion(.failure(.requestFailed))
                }
            }
        }
    }
    
    private func updateStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            authorizationStatus = .authorized
            isAuthorized = true
            error = nil
        case .denied:
            authorizationStatus = .denied
            isAuthorized = false
            error = .denied
        case .restricted:
            authorizationStatus = .restricted
            isAuthorized = false
            error = .restricted
        case .notDetermined:
            authorizationStatus = .notDetermined
            isAuthorized = false
            error = nil
        case .limited:
            authorizationStatus = .limited
            isAuthorized = true
            error = nil
        @unknown default:
            authorizationStatus = .notDetermined
            isAuthorized = false
            error = nil
        }
    }
    
    public func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
    }
    
    private func setupObservers() {
        $authorizationStatus
            .sink { [weak self] status in
                self?.isAuthorized = status.isAuthorized
            }
            .store(in: &cancellables)
    }
}
