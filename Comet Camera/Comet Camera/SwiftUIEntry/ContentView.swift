//
//  ContentView.swift
//  Comet Camera
//
//  Created by zhuangxiaowei on 2026/2/25.
//

import SwiftUI
import Combine
import Comet
import Asset

struct ContentView: View {
    @ObservedObject var viewModel = CCCameraViewModel()
@State var show = false
    @State var items: [CMAsset] = []
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
                        .overlay(
                            CCLensBar(lensControl: viewModel.lensControl)
                                .padding(.bottom, 24)
                            , alignment: .bottom
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                VStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        Button(action: {}) {
                            ZStack {
                                Color.orange
                                    .clipShape(.rect(cornerRadius: 8))
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(lineWidth: 2)
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 50, height: 50)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 50)
                        
                        Button(action: { show.toggle() }) {
                            Circle()
                                .foregroundStyle(.white)
                                .padding(5)
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .stroke(Color.white, lineWidth: 5)
                        )
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.trianglehead.2.clockwise")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 50)
                    }
                    .frame(height: 140, alignment: .top)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .assetPicker(isPresented: $show, selectedAssets: $items)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    
}


#Preview {
    ContentView()
}
