// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftDataPrototype",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftDataPrototype",
            targets: ["SwiftDataPrototype"]),
    ],
    targets: [
        .target(
            name: "SwiftDataPrototype"),
    ]
)
