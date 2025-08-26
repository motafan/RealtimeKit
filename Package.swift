// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealtimeKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        // Main RealtimeKit product that includes all modules
        .library(
            name: "RealtimeKit",
            targets: ["RealtimeKit"]
        ),
        // Core module for basic functionality
        .library(
            name: "RealtimeCore",
            targets: ["RealtimeCore"]
        ),
        // UIKit integration module
        .library(
            name: "RealtimeUIKit",
            targets: ["RealtimeUIKit"]
        ),
        // SwiftUI integration module
        .library(
            name: "RealtimeSwiftUI",
            targets: ["RealtimeSwiftUI"]
        ),
        // Agora provider implementation
        .library(
            name: "RealtimeAgora",
            targets: ["RealtimeAgora"]
        ),
        // Mock provider for testing
        .library(
            name: "RealtimeMocking",
            targets: ["RealtimeMocking"]
        )
    ],
    dependencies: [
        // Agora SDK dependencies (uncomment when ready to integrate real SDK)
        // .package(url: "https://github.com/AgoraIO/AgoraRtcEngine_iOS", from: "4.0.0"),
        // .package(url: "https://github.com/AgoraIO/AgoraRtmKit_iOS", from: "1.5.0")
    ],
    targets: [
        // Main RealtimeKit target that re-exports all modules
        .target(
            name: "RealtimeKit",
            dependencies: [
                "RealtimeCore",
                "RealtimeUIKit",
                "RealtimeSwiftUI",
                "RealtimeAgora"
            ]
        ),
        
        // Core module containing protocols, models, and managers
        .target(
            name: "RealtimeCore",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        
        // UIKit integration module
        .target(
            name: "RealtimeUIKit",
            dependencies: ["RealtimeCore"]
        ),
        
        // SwiftUI integration module
        .target(
            name: "RealtimeSwiftUI",
            dependencies: ["RealtimeCore"]
        ),
        
        // Agora provider implementation
        .target(
            name: "RealtimeAgora",
            dependencies: [
                "RealtimeCore"
                // Add Agora SDK dependencies when ready:
                // .product(name: "AgoraRtcKit", package: "AgoraRtcEngine_iOS"),
                // .product(name: "AgoraRtmKit", package: "AgoraRtmKit_iOS")
            ]
        ),
        
        // Mock provider for testing
        .target(
            name: "RealtimeMocking",
            dependencies: ["RealtimeCore"]
        ),
        
        // Test targets using built-in Swift Testing framework
        .testTarget(
            name: "RealtimeCoreTests",
            dependencies: [
                "RealtimeCore", 
                "RealtimeMocking",
                "RealtimeAgora",
                "RealtimeUIKit",
                "RealtimeSwiftUI"
            ]
        ),
        .testTarget(
            name: "RealtimeMockingTests",
            dependencies: [
                "RealtimeCore", 
                "RealtimeMocking"
            ]
        )
    ]
)