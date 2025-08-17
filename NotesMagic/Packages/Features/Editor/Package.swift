// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Editor",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Editor",
            targets: ["Editor"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../UIComponents")
    ],
    targets: [
        .target(
            name: "Editor",
            dependencies: ["Domain", "UIComponents"]),
        .testTarget(
            name: "EditorTests",
            dependencies: ["Editor"]),
    ]
)
