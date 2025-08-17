// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Domain",
            targets: ["Domain"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Domain",
            dependencies: []),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]),
    ]
)
