// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShuttlX",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        // macOS is declared so `swift test` can run on the developer Mac host.
        // Production code targets iOS/watchOS — macOS support is test-only.
        .macOS(.v12)
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
            // The existing `tests/` directory holds shell + Python build helpers
            // (e.g., build_and_test_both_platforms.sh) — we nest the SPM tests
            // under `tests/ShuttlXTests/` so they coexist. Using the existing
            // casing keeps the path stable across case-sensitive filesystems.
            path: "tests/ShuttlXTests"
        ),
    ]
)
