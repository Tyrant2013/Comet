//
//  CMPhotoEditSliderPreview.swift
//  Comet Camera
//

import SwiftUI

struct EditorTestView: UIViewRepresentable {
    func makeUIView(context: Context) -> CMPhotoEditSlider {
        let vv = CMPhotoEditSlider()
        
        return vv
    }
    
    func updateUIView(_ uiView: CMPhotoEditSlider, context: Context) {
        
    }
}

#Preview {
    EditorTestView()
//        .frame(height: 250)
}
