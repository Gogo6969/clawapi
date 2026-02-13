// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClawAPI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClawAPIApp", targets: ["ClawAPIApp"]),
        .executable(name: "ClawAPIDaemon", targets: ["ClawAPIDaemon"]),
        .executable(name: "clawapi-cli", targets: ["ClawAPICLI"]),
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "ClawAPIApp",
            dependencies: ["Shared"],
            path: "Sources/ClawAPIApp"
        ),
        .executableTarget(
            name: "ClawAPIDaemon",
            dependencies: ["Shared"],
            path: "Sources/ClawAPIDaemon"
        ),
        .executableTarget(
            name: "ClawAPICLI",
            dependencies: ["Shared"],
            path: "Sources/ClawAPICLI"
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: [
                "Shared",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/SharedTests"
        ),
    ]
)
