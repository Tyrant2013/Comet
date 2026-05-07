//
//  SettingsView.swift
//  Comet Camera
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("启动设置")) {
                    Picker("启动时显示", selection: $settingsManager.startupPage) {
                        ForEach(StartupPage.allCases, id: \.self) { page in
                            Text(page.title).tag(page)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
}
