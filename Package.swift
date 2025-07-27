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
        // AI/ML
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.5.0"),
        
        // ネットワーク
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        
        // データベース
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        
        // UI
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "2.2.0"),
        
        // 課金
        .package(url: "https://github.com/RevenueCat/purchases-ios", from: "4.0.0"),
        
        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        
        // Markdown
        .package(url: "https://github.com/johnxnguyen/Down", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "NoteAI",
            dependencies: [
                "WhisperKit",
                "Alamofire",
                .product(name: "GRDB", package: "GRDB.swift"),
                "SDWebImageSwiftUI",
                .product(name: "RevenueCat", package: "purchases-ios"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                "Down"
            ]),
        .testTarget(
            name: "NoteAITests",
            dependencies: ["NoteAI"]),
    ]
)