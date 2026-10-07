// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Extension",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Extension",
            targets: ["Extension"]
        ),
    ],
    targets: [
        .target(
            name: "Extension"
        ),
        .testTarget(
            name: "ExtensionTests",
            dependencies: ["Extension"]
        ),
    ]
)
