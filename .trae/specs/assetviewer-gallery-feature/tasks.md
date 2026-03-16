# Tasks

- [x] Task 1: 创建 AssetViewer 基础模型和数据结构
  - [x] SubTask 1.1: 创建 CMAssetViewer.swift 主视图模型
  - [x] SubTask 1.2: 创建 CMAlbum.swift 相册模型
  - [x] SubTask 1.3: 创建 CMAsset.swift 资源模型
  - [x] SubTask 1.4: 创建 CMAssetCollection.swift 资源集合模型

- [x] Task 2: 实现相册管理功能
  - [x] SubTask 2.1: 实现 CMAlbumManager.swift 相册管理器
  - [x] SubTask 2.2: 实现获取所有相册列表
  - [x] SubTask 2.3: 实现获取相册中的图片
  - [x] SubTask 2.4: 实现创建新相册
  - [x] SubTask 2.5: 实现删除相册

- [x] Task 3: 实现图片加载和缓存
  - [x] SubTask 3.1: 创建 CMImageCache.swift 图片缓存管理器
  - [x] SubTask 3.2: 实现图片懒加载逻辑
  - [x] SubTask 3.3: 实现图片预加载
  - [x] SubTask 3.4: 实现缓存容量管理和清理

- [x] Task 4: 实现 iCloud 图片处理
  - [x] SubTask 4.1: 实现 iCloud 图片状态检测
  - [x] SubTask 4.2: 创建 CMCloudIconView.swift iCloud 图标视图
  - [x] SubTask 4.3: 实现点击下载 iCloud 图片功能
  - [x] SubTask 4.4: 实现下载进度显示

- [x] Task 5: 创建 UI 组件
  - [x] SubTask 5.1: 创建 CMAssetViewerView.swift 主视图
  - [x] SubTask 5.2: 创建 CMAlbumPickerView.swift 相册选择器
  - [x] SubTask 5.3: 创建 CMAssetGridView.swift 图片网格视图
  - [x] SubTask 5.4: 创建 CMAssetCell.swift 图片单元格
  - [x] SubTask 5.5: 创建 CMAlbumEditorView.swift 相册编辑视图

- [x] Task 6: 实现权限管理
  - [x] SubTask 6.1: 实现 PHPhotoLibrary 权限请求
  - [x] SubTask 6.2: 创建权限拒绝提示视图
  - [x] SubTask 6.3: 实现引导用户到系统设置

- [x] Task 7: 实现图片预览功能
  - [x] SubTask 7.1: 创建 CMAssetPreviewView.swift 预览视图
  - [x] SubTask 7.2: 实现全屏图片显示
  - [x] SubTask 7.3: 实现左右滑动切换图片
  - [x] SubTask 7.4: 实现预览模式导航栏
  - [x] SubTask 7.5: 实现返回时滚动到当前图片位置

- [x] Task 8: 实现图片编辑功能
  - [x] SubTask 8.1: 集成 PhotoEditor 库
  - [x] SubTask 8.2: 实现从预览模式进入编辑
  - [x] SubTask 8.3: 实现编辑后保存图片
  - [x] SubTask 8.4: 实现取消编辑功能

- [x] Task 9: 集成和测试
  - [x] SubTask 9.1: 集成所有组件到主视图
  - [x] SubTask 9.2: 测试大量图片加载性能
  - [x] SubTask 9.3: 测试 iCloud 图片处理
  - [x] SubTask 9.4: 测试相册创建和删除功能
  - [x] SubTask 9.5: 测试图片预览和切换功能
  - [x] SubTask 9.6: 测试返回时滚动定位功能
  - [x] SubTask 9.7: 测试图片编辑功能

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 1]
- [Task 4] depends on [Task 1]
- [Task 5] depends on [Task 2, Task 3, Task 4]
- [Task 6] depends on [Task 1]
- [Task 7] depends on [Task 3, Task 5]
- [Task 8] depends on [Task 3, Task 7]
- [Task 9] depends on [Task 2, Task 3, Task 4, Task 5, Task 6, Task 7, Task 8]
