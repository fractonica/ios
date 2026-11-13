// swift-tools-version: 6.0
//
// FractonicaKit: the thin Swift face of the C99 Fractonica core.
//
// The kit contains NO arithmetic of its own. Every number, name, boundary and
// formatted text is fetched from the C module `CFractonica`, which is the
// sibling repository `core/` (depended on by path, never copied).
//
//     swift test            (or ../Tools/test-kit.sh)
//
// See ../AGENTS.md for the map of the sources.

import PackageDescription

let package = Package(
    name: "FractonicaKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "FractonicaKit", targets: ["FractonicaKit"]),
    ],
    dependencies: [
        // The package identity is the directory name: "core".
        .package(path: "../../core"),
    ],
    targets: [
        .target(
            name: "FractonicaKit",
            dependencies: [.product(name: "CFractonica", package: "core")]
        ),
        .testTarget(
            name: "FractonicaKitTests",
            dependencies: ["FractonicaKit"]
        ),
    ]
)
