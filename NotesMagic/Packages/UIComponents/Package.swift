// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UIComponents",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "UIComponents",
            targets: ["UIComponents"]),
    ],
    dependencies: [
        .package(path: "../Domain")
    ],
    targets: [
        .target(
            name: "UIComponents",
            dependencies: ["Domain"],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "UIComponentsTests",
            dependencies: ["UIComponents"]),
    ]
)
