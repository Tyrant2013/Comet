//
//  SwiftUIView.swift
//  Comet
//

import SwiftUI
import Photos

struct CMPhotoPreview: View {
    let fetchResult: CMFetchResult<PHAsset>
    @Binding var index: Int
    
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            CMPhotoBrowserView(
                fetchResult: fetchResult,
                index: $index
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal)
                .frame(height: 44)
                .background(Color.black.ignoresSafeArea())
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct CMPhotoBrowserView: UIViewControllerRepresentable {
    let fetchResult: CMFetchResult<PHAsset>
    @Binding var index: Int
    func makeUIViewController(context: Context) -> CMPhotoBrowserViewController {
        let dataSource = CMDatasource(fetchResult: fetchResult)
        let vc = CMPhotoBrowserViewController(dataSource: dataSource, initialIndex: index)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: CMPhotoBrowserViewController, context: Context) {
        
    }
}

#Preview {
//    CMPhotoBrowserView(fetchResult: CMFetchResult(result: nil), index: .constant(0))
    ExaView()
}


struct ExaView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ExampleViewController {
        let vc = ExampleViewController()
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ExampleViewController, context: Context) {
        
    }
}
