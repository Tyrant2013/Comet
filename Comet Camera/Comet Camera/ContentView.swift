//
//  ContentView.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var viewModel = CCCameraViewModel()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("PreviewImage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topTrailing)
                VStack(spacing: 0) {
                    Spacer()
                    CCLensBar(lensControl: viewModel.lensControl)
                        .padding(.bottom, 24)
                    
                    Button(action: {}) {
                        Circle()
                            .foregroundStyle(.white)
                            .padding(5)
                    }
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .stroke(Color.white, lineWidth: 5)
                    )
                    .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        
    }
    
    
}


#Preview {
    ContentView()
}
