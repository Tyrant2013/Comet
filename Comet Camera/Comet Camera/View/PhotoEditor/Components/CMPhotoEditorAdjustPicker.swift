//
//  CMPhotoEditorAdjustPicker.swift
//  Comet Camera
//

import SwiftUI



struct CMPhotoEditorAdjustPicker: View {
    let items: [CMPhotoAdjustItem]
    let itemDidChanged: (_ value: CMPhotoAdjustItem) -> Void
    
    @State private var selectedItem: CMPhotoAdjustItem = .defaultAdjustItem()
    @Namespace var animationSpace
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollReader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(items) { item in
                            CMAdjustItemView(
                                item: item,
                                selected: selectedItem == item,
                                animationSpace: animationSpace,
                                action: {
                                    selectedItem = item
                                    withAnimation {
                                        scrollReader.scrollTo(item.id, anchor: .center)
                                    }
                                    itemDidChanged(item)
                                }
                            )
                            .id(item.id)
                            .frame(width: 80, height: 40)
                        }
                    }
                    .padding(.horizontal, geometry.size.width / 2 - 40)
                }
            }
        }
        .animation(.default, value: selectedItem)
        .frame(height: 40)
        .background(
            LinearGradient(
                colors: [
                    .white.opacity(0.1),
                    .white.opacity(0.3),
                    .white.opacity(0.8),
                    .white,
                    .white.opacity(0.8),
                    .white.opacity(0.3),
                    .white.opacity(0.1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    struct CMAdjustItemView: View {
        let item: CMPhotoAdjustItem
        let selected: Bool
        let animationSpace: Namespace.ID
        let action: () -> Void
        var body: some View {
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black)
                .background(bottomLine, alignment: .bottom)
                .contentShape(.rect)
                .onTapGesture(perform: action)
        }
        
        @ViewBuilder
        var bottomLine: some View {
            if selected {
                Capsule()
                    .frame(height: 6)
                    .foregroundStyle(.orange)
                    .matchedGeometryEffect(id: "BottomLine", in: animationSpace)
            }
        }
    }
}


#Preview {
    CMPhotoEditorAdjustPicker(items: CMPhotoAdjustItem.supportedAdjustItems()) { value in
        
    }
}
