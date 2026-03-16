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
                VStack {
                    HStack {
                        
                    }
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    let width = proxy.size.width - 20
                    let height = width * 9 / 6
                    Image("PreviewImage")
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipShape(.rect(cornerRadius: 8))
                        .frame(width: width + 10, height: height + 10)
                        .background(Color.black)
                        .clipShape(.rect(cornerRadius: 14))
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
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
        
    }
    
    
}


#Preview {
    ContentView()
}
