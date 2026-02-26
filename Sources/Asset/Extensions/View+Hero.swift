import SwiftUI

/// Hero动画扩展
extension View {
    /// 添加Hero动画
    /// - Parameter id: 动画标识符
    /// - Returns: 处理后的视图
    func hero(id: String) -> some View {
        self.modifier(HeroModifier(id: id))
    }
}

/// Hero动画修饰符
struct HeroModifier: ViewModifier {
    /// 动画标识符
    let id: String
    /// 动画状态
    @State private var isActive: Bool = false
    
    /// 主体内容
    /// - Parameter content: 原始内容
    /// - Returns: 处理后的内容
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0 : 1)
            .onAppear {
                // 触发动画
                withAnimation(.easeInOut(duration: 0.3)) {
                    isActive = true
                }
                
                // 动画结束后重置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isActive = false
                }
            }
    }
}

/// Hero动画容器
struct HeroAnimationContainer<Content: View>: View {
    /// 内容构建器
    let content: () -> Content
    /// 是否显示
    @Binding var isVisible: Bool
    
    /// 初始化
    /// - Parameters:
    ///   - isVisible: 是否显示
    ///   - content: 内容构建器
    init(isVisible: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._isVisible = isVisible
        self.content = content
    }
    
    /// 主体内容
    var body: some View {
        ZStack {
            if isVisible {
                content()
                    .transition(.scale(scale: 0.8, anchor: .center).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isVisible)
            }
        }
    }
}