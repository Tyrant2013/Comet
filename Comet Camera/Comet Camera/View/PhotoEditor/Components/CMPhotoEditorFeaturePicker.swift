//
//  CMPhotoEditorFeaturePicker.swift
//  Comet Camera
//

import SwiftUI

struct CMPhotoEditorFeaturePicker: View {
    @State var selectedIndex: Int = 0
    
    @Namespace var animationSpace
    var body: some View {
        HStack(spacing: 0) {
            CMPhotoEditorFeatureItemView(
                title: "调整",
                selected: selectedIndex == 0,
                action: { selectedIndex = 0 },
                nameSpace: animationSpace)
            CMPhotoEditorFeatureItemView(
                title: "剪裁",
                selected: selectedIndex == 1,
                action: { selectedIndex = 1 },
                nameSpace: animationSpace)
        }
        .frame(height: 40)
        .animation(.spring, value: selectedIndex)
        .padding(.horizontal)
        .background(Color.white, in: .capsule)
    }
    
    struct CMPhotoEditorFeatureItemView: View {
        let title: String
        let selected: Bool
        let action: () -> Void
        let nameSpace: Namespace.ID
        
        var body: some View {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
                .frame(height: 30)
                .overlay(selectedBar, alignment: .bottom)
                .padding(.horizontal)
                .contentShape(.rect)
                .onTapGesture(perform: action)
        }
        
        @ViewBuilder
        private var selectedBar: some View {
            if selected {
                Capsule()
                    .frame(height: 2)
                    .foregroundStyle(.orange)
                    .matchedGeometryEffect(id: "SelectedBar", in: nameSpace)
            }
        }
    }
}

//#Preview {
//    CMPhotoEditorFeaturePicker()
//}
