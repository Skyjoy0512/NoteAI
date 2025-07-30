// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SQLiteDirectPrototype",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SQLiteDirectPrototype",
            targets: ["SQLiteDirectPrototype"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .target(
            name: "SQLiteDirectPrototype",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ]),
    ]
)
