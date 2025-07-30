// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NoteAI",
            targets: ["NoteAI"])
    ],
    dependencies: [
        // 基本的なUI
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.2.0"),
        
        // ネットワーク
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0")
    ],
    targets: [
        .executableTarget(
            name: "NoteAI",
            dependencies: [
                "SDWebImageSwiftUI",
                "Alamofire"
            ],
            path: "Sources/NoteAI",
            resources: [
                .process("Resources", localization: .none)
            ],
            swiftSettings: [
                .define("MINIMAL_BUILD"),
                .define("NO_COREDATA")
            ]),
        .testTarget(
            name: "NoteAITests",
            dependencies: ["NoteAI"],
            path: "Tests/NoteAITests"),
    ]
)
