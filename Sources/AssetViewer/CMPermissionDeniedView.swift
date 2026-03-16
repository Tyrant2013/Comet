//
//  CMPermissionDeniedView.swift
//  Comet
//
//  Created by zhuangxiaowei on 2026/3/12.
//

import SwiftUI

public struct CMPermissionDeniedView: View {
    @ObservedObject private var permissionManager: CMPermissionManager
    
    private let title: String
    private let message: String
    private let iconName: String
    private let onRetry: (() -> Void)?
    
    public init(
        permissionManager: CMPermissionManager = .shared,
        title: String = "需要相册访问权限",
        message: String? = nil,
        iconName: String = "photo.on.rectangle.angled",
        onRetry: (() -> Void)? = nil
    ) {
        self.permissionManager = permissionManager
        self.title = title
        self.message = message ?? "为了浏览和管理您的照片，我们需要访问您的相册。请在系统设置中开启相册权限。"
        self.iconName = iconName
        self.onRetry = onRetry
    }
    
    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            iconView
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            
            actionButtons
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("前往系统设置")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Text("重新请求权限")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func openSettings() {
        permissionManager.openSettings()
    }
}

public struct CMPermissionRestrictedView: View {
    @ObservedObject private var permissionManager: CMPermissionManager
    
    private let title: String
    private let message: String
    private let iconName: String
    
    public init(
        permissionManager: CMPermissionManager = .shared,
        title: String = "相册访问受限",
        message: String? = nil,
        iconName: String = "lock.fill"
    ) {
        self.permissionManager = permissionManager
        self.title = title
        self.message = message ?? "由于设备限制，无法访问相册。请检查家长控制或设备管理设置。"
        self.iconName = iconName
    }
    
    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            iconView
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.orange)
        }
    }
}

public struct CMPermissionView: View {
    @ObservedObject private var permissionManager: CMPermissionManager
    
    private let title: String
    private let message: String
    private let iconName: String
    private let onAuthorized: (() -> Void)?
    
    public init(
        permissionManager: CMPermissionManager = .shared,
        title: String = "需要相册访问权限",
        message: String? = nil,
        iconName: String = "photo.on.rectangle.angled",
        onAuthorized: (() -> Void)? = nil
    ) {
        self.permissionManager = permissionManager
        self.title = title
        self.message = message ?? "为了浏览和管理您的照片，我们需要访问您的相册。"
        self.iconName = iconName
        self.onAuthorized = onAuthorized
    }
    
    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            switch permissionManager.authorizationStatus {
            case .notDetermined:
                permissionRequestView
            case .denied:
                CMPermissionDeniedView(
                    permissionManager: permissionManager,
                    title: title,
                    message: message ?? "相册访问权限被拒绝。请在系统设置中开启相册权限。",
                    iconName: iconName,
                    onRetry: requestPermission
                )
            case .restricted:
                CMPermissionRestrictedView(
                    permissionManager: permissionManager,
                    title: title,
                    message: message ?? "相册访问受限，无法访问相册。",
                    iconName: "lock.fill"
                )
            case .authorized, .limited:
                Color.clear
                    .onAppear {
                        onAuthorized?()
                    }
            }
        }
    }
    
    @ViewBuilder
    private var permissionRequestView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            iconView
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)
            
            Button(action: requestPermission) {
                Text("允许访问相册")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(24)
    }
    
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: iconName)
                .font(.system(size: 50))
                .foregroundColor(.blue)
        }
    }
    
    private func requestPermission() {
        permissionManager.requestAuthorization { result in
            if case .success = result {
                onAuthorized?()
            }
        }
    }
}

struct CMPermissionDeniedView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CMPermissionDeniedView()
                .previewDisplayName("Permission Denied")
            
            CMPermissionRestrictedView()
                .previewDisplayName("Permission Restricted")
            
            CMPermissionView()
                .previewDisplayName("Permission View")
        }
    }
}
