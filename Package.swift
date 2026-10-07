// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Composition",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Composition",
            targets: ["Composition"]
        ),
    ],
    targets: [
        .target(
            name: "Composition"
        ),
        .testTarget(
            name: "CompositionTests",
            dependencies: ["Composition"]
        ),
    ]
)
