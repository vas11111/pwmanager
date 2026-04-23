// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PWManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PWManagerCore",
            targets: ["PWManagerCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/leif-ibsen/SwiftKyber", from: "3.5.0"),
        .package(url: "https://github.com/dugleelabs/swift-argon2.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PWManagerCore",
            dependencies: [
                "SwiftKyber",
                .product(name: "Argon2", package: "swift-argon2"),
            ],
            path: "Sources/PWManagerCore"
        ),
        .executableTarget(
            name: "PWManagerApp",
            dependencies: ["PWManagerCore"],
            path: "Sources/PWManagerApp",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "PWManagerCoreTests",
            dependencies: ["PWManagerCore"],
            path: "Tests/PWManagerCoreTests"
        )
    ]
)
