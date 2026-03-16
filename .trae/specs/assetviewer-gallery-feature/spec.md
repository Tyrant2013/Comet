# AssetViewer 系统相册浏览功能 Spec

## Why
用户需要在应用中浏览系统相册中的图片，包括查看所有图片、切换不同相册、管理相册（添加/删除），并需要处理大量图片时的性能优化以及 iCloud 图片未下载的情况。

## What Changes
- 在 Sources/Camera 下创建 AssetViewer 文件夹
- 实现相册浏览功能，包括：
  - 默认显示所有图片
  - 支持切换相册
  - 支持添加和删除相册
  - 优化大量图片加载性能
  - 处理 iCloud 图片未下载状态，显示 iCloud 图标
  - 点击图片进入预览模式
  - 预览模式下左右切换图片
  - 返回时滚动到当前预览的图片
  - 预览模式下支持编辑功能，使用 PhotoEditor 库
- 添加必要的模型、视图和视图控制器

## Impact
- Affected specs: 无
- Affected code: Sources/Camera/AssetViewer (新建)

## ADDED Requirements

### Requirement: 相册浏览功能
系统 SHALL 提供一个完整的相册浏览界面，允许用户查看和管理系统相册中的图片。

#### Scenario: 启动时显示所有图片
- **WHEN** 用户打开 AssetViewer
- **THEN** 默认显示系统相册中的所有图片
- **AND** 图片按时间倒序排列

#### Scenario: 切换相册
- **WHEN** 用户选择不同的相册
- **THEN** 显示所选相册中的图片
- **AND** 更新当前相册标题

#### Scenario: 添加相册
- **WHEN** 用户创建新相册并命名
- **THEN** 新相册被添加到系统相册
- **AND** 用户可以切换到新相册

#### Scenario: 删除相册
- **WHEN** 用户删除一个相册
- **THEN** 该相册从系统相册中移除
- **AND** 相册中的图片保留在所有图片中

### Requirement: 性能优化
系统 SHALL 优化大量图片加载的性能，确保流畅的用户体验。

#### Scenario: 懒加载图片
- **WHEN** 用户滚动浏览大量图片
- **THEN** 只加载可见区域的图片
- **AND** 预加载即将显示的图片

#### Scenario: 图片缓存
- **WHEN** 用户已加载过图片
- **THEN** 图片被缓存以避免重复加载
- **AND** 缓存有合理的容量限制

### Requirement: iCloud 图片处理
系统 SHALL 正确处理存储在 iCloud 上的图片，并在未下载时显示 iCloud 图标。

#### Scenario: 显示 iCloud 图标
- **WHEN** 图片存储在 iCloud 且未下载
- **THEN** 在图片上显示 iCloud 图标
- **AND** 用户可以点击下载图片

#### Scenario: 下载 iCloud 图片
- **WHEN** 用户点击 iCloud 图片
- **THEN** 系统开始下载图片
- **AND** 下载完成后显示完整图片

### Requirement: 权限管理
系统 SHALL 正确处理相册访问权限。

#### Scenario: 请求权限
- **WHEN** 用户首次打开 AssetViewer
- **THEN** 系统请求相册访问权限
- **AND** 如果权限被拒绝，显示提示信息

#### Scenario: 权限被拒绝
- **WHEN** 用户拒绝相册访问权限
- **THEN** 显示权限请求提示
- **AND** 引导用户到系统设置中开启权限

### Requirement: 图片预览功能
系统 SHALL 提供图片预览功能，允许用户全屏查看图片并切换浏览。

#### Scenario: 进入预览模式
- **WHEN** 用户点击网格中的图片
- **THEN** 进入全屏预览模式
- **AND** 显示当前选中的图片

#### Scenario: 左右切换图片
- **WHEN** 用户在预览模式下左右滑动
- **THEN** 切换到上一张或下一张图片
- **AND** 支持手势滑动和点击按钮切换

#### Scenario: 返回时滚动定位
- **WHEN** 用户从预览模式返回到网格视图
- **THEN** 网格视图自动滚动到当前预览的图片位置
- **AND** 保持图片的可见性

### Requirement: 图片编辑功能
系统 SHALL 在预览模式下提供编辑功能，使用 PhotoEditor 库进行图片编辑。

#### Scenario: 进入编辑模式
- **WHEN** 用户在预览模式下点击编辑按钮
- **THEN** 使用 PhotoEditor 打开当前图片
- **AND** 显示 PhotoEditor 的编辑界面

#### Scenario: 保存编辑后的图片
- **WHEN** 用户完成编辑并保存
- **THEN** 编辑后的图片保存到相册
- **AND** 返回预览模式显示更新后的图片

#### Scenario: 取消编辑
- **WHEN** 用户取消编辑
- **THEN** 返回预览模式
- **AND** 原始图片保持不变
