//
//  CMPhotoAdjusterView.swift
//  Comet Camera
//
//  Created by 桃园谷 on 2026/4/1.
//

import SwiftUI

struct CMPhotoAdjusterView: View {
    var body: some View {
        ZStack {
            
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(lineWidth: 2)
                .foregroundStyle(.white.opacity(0.4))
        )
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
//        .background(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    CMPhotoAdjusterView()
}
