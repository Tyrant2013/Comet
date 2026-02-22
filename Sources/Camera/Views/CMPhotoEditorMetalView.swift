import Foundation
import SwiftUI
import UIKit
import CoreImage

public struct CMPhotoEditorMetalView: UIViewRepresentable {
    let image: CIImage?
    let imageContentMode: CMPhotoEditorContentMode
    
    public init(image: CIImage?, imageContentMode: CMPhotoEditorContentMode = .scaleAspectFit) {
        self.image = image
        self.imageContentMode = imageContentMode
    }
    
    public func makeUIView(context: Context) -> CMPhotoEditorMTKView {
        let view = CMPhotoEditorMTKView()
        view.image = image
        view.imageContentMode = imageContentMode
        return view
    }
    
    public func updateUIView(_ uiView: CMPhotoEditorMTKView, context: Context) {
        uiView.image = image
        uiView.imageContentMode = imageContentMode
    }
}
