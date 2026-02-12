# Swift 相机库功能扩展需求

## 任务目标
为现有的 Swift 公共相机库添加以下功能：
1. **前后摄像头切换** - 在运行时切换前置/后置摄像头
2. **焦距切换** - 支持多镜头系统（广角、超广角、长焦）的切换

## 技术要求

### 开发环境
- 语言：Swift 5.9+
- 框架：AVFoundation
- 目标平台：iOS 14.0+
- UI 框架：UIKit（Demo 页面使用）

### 功能规格

#### 1. 前后摄像头切换
- 实现 `switchCamera()` 方法
- 支持平滑过渡动画（使用 `AVCaptureDevice.DiscoverySession`）
- 处理权限检查（前置摄像头需要麦克风权限时给出提示）
- 切换时保持当前的曝光、对焦模式设置
- 错误处理：当前置/后置不可用时给出友好提示

#### 2. 焦距切换（多镜头支持）
- 检测设备支持的所有可用镜头（.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera）
- 实现 `switchLens(to: LensType)` 方法
- 支持以下镜头类型枚举：
  ```swift
  enum LensType {
      case ultraWide    // 超广角 0.5x
      case wide         // 广角 1x
      case telephoto    // 长焦 2x/3x
  }
- 在切换镜头时保持预览流不中断（使用 AVCaptureMultiCamSession 或平滑切换策略）
- 提供 getAvailableLenses() -> [LensType] 查询当前设备支持的镜头

### UI Demo 页面要求
#### 1. 在现有 Demo 页面中添加以下 UI 控件用于测试：
- 布局（竖屏）
┌─────────────────────────┐
│                         │
│      相机预览视图        │  ← 全屏或 16:9 比例
│                         │
│                         │
├─────────────────────────┤
│  [0.5x] [1x] [2x] [3x] │  ← 焦距选择按钮（仅显示设备支持的）
├─────────────────────────┤
│  🔄 切换前后摄像头       │  ← 底部中央切换按钮
└─────────────────────────┘
### UI 组件规格
#### 1. 焦距选择器
使用 UISegmentedControl 或自定义按钮组
动态显示设备支持的焦距选项（根据 getAvailableLenses() 结果）
当前选中的焦距高亮显示
点击切换时显示加载指示器
#### 2. 前后摄像头切换按钮
位于底部中央
使用系统图标（arrow.triangle.2.circlepath.camera）
切换时按钮旋转动画
不支持前置/后置时按钮置灰
#### 3. 状态指示
顶部显示当前摄像头位置（前置/后置）
显示当前镜头类型（广角/长焦等）
#### 4. 交互细节
焦距切换动画时长：0.3 秒
摄像头切换动画：翻转效果（使用 UIView transition）
所有操作需有错误提示（使用 UIAlertController）