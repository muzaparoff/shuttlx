// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShuttlX",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "ShuttlXShared",
            targets: ["ShuttlXShared"]),
    ],
    dependencies: [
        // Add your dependencies here
    ],
    targets: [
        .target(
            name: "ShuttlXShared",
            dependencies: [],
            path: "Shared"
        ),
        .testTarget(
            name: "ShuttlXTests",
            dependencies: ["ShuttlXShared"],
            path: "Tests"
        ),
    ]
)
