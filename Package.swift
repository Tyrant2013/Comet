// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Comet",
    platforms: [.iOS(.v15)],
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
        // 相册访问功能
        .library(
            name: "Asset",
            targets: ["Asset"]),
        .executable(name: "CometDemo", targets: ["CometDemo"]),
        // .executable(name: "Comet_Camera", targets: ["Comet_Camera"])
    ],
    targets: [
        .target(
            name: "Comet", dependencies: ["Camera", "PhotoEditor", "Asset"]),
        .target(
            name: "Camera", dependencies: ["PhotoEditor"], path: "Sources/Camera", resources: [.process("Res")]),
        .target(
            name: "PhotoEditor", path: "Sources/PhotoEditor"),
        .target(
            name: "Asset", dependencies: ["PhotoEditor"], path: "Sources/Asset", resources: [.process("Res")]),
        .executableTarget(name: "CometDemo", dependencies: ["Comet"], path: "CometDemo/CometDemo"),
        // .executableTarget(name: "Comet_Camera", dependencies: ["Comet"], path: "Comet Camera/Comet Camera"),
        .testTarget(
            name: "PhotoEditorTests",
            dependencies: ["PhotoEditor"],
            path: "Tests/PhotoEditorTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
