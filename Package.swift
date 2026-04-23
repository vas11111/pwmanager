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
        .package(url: "https://github.com/leif-ibsen/SwiftKyber", exact: "3.5.0"),
    ],
    targets: [
        // Vendored C implementation of Argon2 (phc-winner-argon2)
        .target(
            name: "CArgon2",
            path: "Sources/CArgon2",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("."), .headerSearchPath("blake2")]
        ),
        // Swift wrapper around vendored CArgon2
        .target(
            name: "VendoredArgon2",
            dependencies: ["CArgon2"],
            path: "Sources/VendoredArgon2"
        ),
        .target(
            name: "PWManagerCore",
            dependencies: [
                "SwiftKyber",
                "VendoredArgon2",
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
