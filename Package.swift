// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdaptiveShowcase",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "AdaptiveShowcase",
            targets: ["AdaptiveShowcase"]
        )
    ],
    targets: [
        .target(name: "AdaptiveShowcase"),
        .testTarget(
            name: "AdaptiveShowcaseTests",
            dependencies: ["AdaptiveShowcase"]
        )
    ]
)
