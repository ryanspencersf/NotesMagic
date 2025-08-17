// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Library",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Library",
            targets: ["Library"]),
    ],
    dependencies: [
        .package(path: "../../Domain"),
        .package(path: "../../Data"),
        .package(path: "../../UIComponents")
    ],
    targets: [
        .target(
            name: "Library",
            dependencies: ["Domain", "Data", "UIComponents"]),
        .testTarget(
            name: "LibraryTests",
            dependencies: ["Library"]),
    ]
)
