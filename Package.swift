// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SQLele",
    platforms: [.macOS(.v10_10), .iOS(.v9)],
    products: [
        .library(
            name: "SQLele",
            targets: ["SQLele"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SQLele",
            dependencies: []),
        .testTarget(
            name: "SQLeleTests",
            dependencies: ["SQLele"]),
    ]
)

#if os(Linux)
    package.dependencies += [.package(url: "https://github.com/groue/CSQLite.git", from: "0.3.0")]
#endif
