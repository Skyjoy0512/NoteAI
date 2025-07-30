// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NoteAI",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NoteAI",
            targets: ["NoteAI"]),
    ],
    dependencies: [
        // 軽量な依存関係のみ - 動作確認用
    ],
    targets: [
        .target(
            name: "NoteAI",
            dependencies: [
                // 依存関係なしでコンパイルチェック
            ],
            path: "Sources/NoteAI",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "NoteAITests",
            dependencies: ["NoteAI"],
            path: "Tests/NoteAITests"),
    ]
)