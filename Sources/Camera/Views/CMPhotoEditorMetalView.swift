import Foundation
import SwiftUI
import UIKit
import CoreImage

public struct CMPhotoEditorMetalView: UIViewRepresentable {
    let image: CIImage?
    
    public init(image: CIImage?) {
        self.image = image
    }
    
    public func makeUIView(context: Context) -> CMPhotoEditorMTKView {
        let view = CMPhotoEditorMTKView()
        view.image = image
        return view
    }
    
    public func updateUIView(_ uiView: CMPhotoEditorMTKView, context: Context) {
        uiView.image = image
    }
}
