//
//  CMPhotoEditorAdjustPicker.swift
//  Comet Camera
//

import SwiftUI

struct CMPhotoAdjustItem: Identifiable, Equatable {
    var id: Int
    let title: String
}

struct CMPhotoEditorAdjustPicker: View {
    let items: [CMPhotoAdjustItem] = [
        CMPhotoAdjustItem(id: 1,  title: "曝光"),
        CMPhotoAdjustItem(id: 2,  title: "鲜明度"),
        CMPhotoAdjustItem(id: 3,  title: "高光"),
        CMPhotoAdjustItem(id: 4,  title: "阴影"),
        CMPhotoAdjustItem(id: 5,  title: "对比度"),
        CMPhotoAdjustItem(id: 6,  title: "亮度"),
        CMPhotoAdjustItem(id: 7,  title: "黑点"),
        CMPhotoAdjustItem(id: 8,  title: "饱和度"),
        CMPhotoAdjustItem(id: 9,  title: "自然饱和度"),
        CMPhotoAdjustItem(id: 10, title: "色温"),
        CMPhotoAdjustItem(id: 11, title: "色调"),
        CMPhotoAdjustItem(id: 12, title: "锐度"),
        CMPhotoAdjustItem(id: 13, title: "清晰度"),
        CMPhotoAdjustItem(id: 14, title: "噪点消除"),
        CMPhotoAdjustItem(id: 15, title: "晕影")
    ]
    let itemDidChanged: (_ value: CMPhotoAdjustItem) -> Void
    
    @State private var selectedItem: CMPhotoAdjustItem = CMPhotoAdjustItem(id: 1,  title: "曝光")
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(items) { item in
                        CMAdjustItemView(
                            item: item,
                            selected: selectedItem == item,
                            action: { selectedItem = item }
                        )
                        .frame(width: 80, height: 40)
                    }
                }
                .padding(.horizontal, geometry.size.width / 2 - 40)
            }
        }
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
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
    }
}


#Preview {
    CMPhotoEditorAdjustPicker { value in
        
    }
}
