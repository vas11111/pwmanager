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
    targets: [
        // Vendored: phc-winner-argon2 reference C implementation
        .target(
            name: "CArgon2",
            path: "Sources/CArgon2",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("."), .headerSearchPath("blake2")]
        ),
        // Vendored: Swift wrapper around CArgon2
        .target(
            name: "VendoredArgon2",
            dependencies: ["CArgon2"],
            path: "Sources/VendoredArgon2"
        ),
        // Vendored: leif-ibsen/BigInt v1.23.0
        .target(
            name: "VendoredBigInt",
            path: "Sources/VendoredBigInt",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Vendored: leif-ibsen/ASN1 v2.7.0 (depends on BigInt)
        .target(
            name: "VendoredASN1",
            dependencies: ["VendoredBigInt"],
            path: "Sources/VendoredASN1",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Vendored: leif-ibsen/Digest v1.13.0
        .target(
            name: "VendoredDigest",
            path: "Sources/VendoredDigest",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Vendored: leif-ibsen/SwiftKyber v3.5.0 (depends on ASN1, BigInt, Digest)
        .target(
            name: "VendoredKyber",
            dependencies: ["VendoredASN1", "VendoredBigInt", "VendoredDigest"],
            path: "Sources/VendoredKyber",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "PWManagerCore",
            dependencies: [
                "VendoredKyber",
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
        .executableTarget(
            name: "BackupVerifier",
            dependencies: ["PWManagerCore"],
            path: "Sources/BackupVerifier"
        ),
        .testTarget(
            name: "PWManagerCoreTests",
            dependencies: ["PWManagerCore"],
            path: "Tests/PWManagerCoreTests"
        )
    ]
)
