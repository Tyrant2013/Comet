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
    ],
    targets: [
        .target(
            name: "Comet", dependencies: ["Camera", "PhotoEditor"]),
        .target(
            name: "Camera", dependencies: ["PhotoEditor"], path: "Sources/Camera"),
        .target(
            name: "PhotoEditor", path: "Sources/PhotoEditor"),
        .testTarget(
            name: "PhotoEditorTests",
            dependencies: ["PhotoEditor"],
            path: "Tests/PhotoEditorTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
