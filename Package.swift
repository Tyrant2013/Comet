// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Comet",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "Comet",
            targets: ["Comet"]),
        // 相机相关功能
        .library(
            name: "Camera",
            targets: ["Camera"]),
        // 图片编辑相关功能
        .library(
            name: "PhotoEditor",
            targets: ["PhotoEditor"]),
        .library(
            name: "AssetViewer",
            targets: ["AssetViewer"])
    ],
    targets: [
        .target(
            name: "Comet", dependencies: ["Camera", "PhotoEditor", "AssetViewer"]),
        .target(
            name: "Camera", dependencies: ["PhotoEditor"], path: "Sources/Camera"),
        .target(
            name: "PhotoEditor", path: "Sources/PhotoEditor"),
        .target(
            name: "AssetViewer", dependencies: ["PhotoEditor"], path: "Sources/AssetViewer"),
        .testTarget(
            name: "PhotoEditorTests",
            dependencies: ["PhotoEditor"],
            path: "Tests/PhotoEditorTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
