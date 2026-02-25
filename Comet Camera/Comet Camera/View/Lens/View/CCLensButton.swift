//
//  CCLensButton.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI

struct CCLensButton: View {
    let lens: CCLens
    let isSelected: Bool
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(.white)
                .opacity(isSelected ? 0.8 : 0.3)
            Text("\(lens.id)x")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
        }
        .frame(width: 28, height: 28)
    }
}

#Preview {
    CCLensButton(lens: CCLens(id: ".5"), isSelected: false)
}
