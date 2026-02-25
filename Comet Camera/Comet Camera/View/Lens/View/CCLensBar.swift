//
//  CCLensBar.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI

struct CCLensBar: View {
    @ObservedObject var lensControl: CCLensControl
    var body: some View {
        HStack(spacing: 8) {
            ForEach(lensControl.visibleLens, id: \.id) { lens in
                CCLensButton(lens: lens, isSelected: lens == lensControl.currentLens)
                    .onTapGesture {
                        lensControl.change(to: lens)
                    }
            }
        }
        .frame(width: 240, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.white.opacity(0.3))
                .opacity(0)
        )
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged({ isPress in
                    print("\(isPress)")
                })
//                .simultaneously(with: TapGesture(count: 1))
        )
    }
}

#Preview {
    CCLensBar(lensControl: CCLensControl())
        .background(Color.black)
}
