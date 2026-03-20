import SwiftUI

/// 相册选择器
public struct CMAssetPicker {
    /// 显示相册选择器
    /// - Parameters:
    ///   - isPresented: 是否显示
    ///   - selectedAssets: 选中的图片列表
    ///   - allowsMultipleSelection: 是否允许多选
    public static func show(
        isPresented: Binding<Bool>,
        selectedAssets: Binding<[CMAsset]>,
        allowsMultipleSelection: Bool = true
    ) -> some View {
        return ZStack {
            if isPresented.wrappedValue {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented.wrappedValue = false
                    }
                
                CMAssetPickerView()
                    .frame(maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

/// 视图扩展
extension View {
    /// 显示相册选择器
    /// - Parameters:
    ///   - isPresented: 是否显示
    ///   - selectedAssets: 选中的图片列表
    ///   - allowsMultipleSelection: 是否允许多选
    public func assetPicker(
        isPresented: Binding<Bool>,
        selectedAssets: Binding<[CMAsset]>,
        allowsMultipleSelection: Bool = true
    ) -> some View {
        self.fullScreenCover(isPresented: isPresented) {
            CMAssetPickerView()
        }
//        ZStack {
//            self
//            CMAssetPicker.show(
//                isPresented: isPresented,
//                selectedAssets: selectedAssets,
//                allowsMultipleSelection: allowsMultipleSelection
//            )
//        }
    }
}

/// 圆角扩展
extension View {
    /// 设置指定角的圆角
    /// - Parameters:
    ///   - radius: 圆角半径
    ///   - corners: 要设置的角
    /// - Returns: 处理后的视图
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// 圆角形状
struct RoundedCorner: Shape {
    /// 圆角半径
    var radius: CGFloat
    /// 要设置的角
    var corners: UIRectCorner
    
    /// 路径
    /// - Parameter rect: 矩形
    /// - Returns: 路径
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
