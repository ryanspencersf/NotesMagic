// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NotesMagic",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NotesMagic",
            targets: ["NotesMagic"]
        ),
    ],
    dependencies: [
        // Local package dependencies
    ],
    targets: [
        .target(
            name: "NotesMagic",
            dependencies: [
                "Domain",
                "Data", 
                "Editor",
                "Library",
                "Onboarding",
                "UIComponents",
                "MLKit"
            ],
            path: "NotesMagic"
        ),
        .target(
            name: "Domain",
            path: "Packages/Domain"
        ),
        .target(
            name: "Data",
            dependencies: ["Domain"],
            path: "Packages/Data"
        ),
        .target(
            name: "Editor",
            dependencies: ["Domain", "UIComponents"],
            path: "Packages/Features/Editor"
        ),
        .target(
            name: "Library",
            dependencies: ["Domain", "Data", "UIComponents"],
            path: "Packages/Features/Library"
        ),
        .target(
            name: "Onboarding",
            dependencies: ["Domain", "UIComponents"],
            path: "Packages/Features/Onboarding"
        ),
        .target(
            name: "UIComponents",
            dependencies: ["Domain"],
            path: "Packages/UIComponents"
        ),
        .target(
            name: "MLKit",
            dependencies: ["Domain"],
            path: "Packages/MLKit"
        ),
        .testTarget(
            name: "NotesMagicTests",
            dependencies: ["NotesMagic"],
            path: "NotesMagicTests"
        ),
        .testTarget(
            name: "NotesMagicUITests",
            dependencies: ["NotesMagic"],
            path: "NotesMagicUITests"
        )
    ]
)
