// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EnglishPocket",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EnglishPocketCore",
            targets: ["EnglishPocketCore"]
        ),
        .executable(
            name: "EnglishPocketMac",
            targets: ["EnglishPocketMac"]
        )
    ],
    targets: [
        .target(
            name: "EnglishPocketCore"
        ),
        .executableTarget(
            name: "EnglishPocketMac",
            dependencies: ["EnglishPocketCore"]
        ),
        .testTarget(
            name: "EnglishPocketCoreTests",
            dependencies: ["EnglishPocketCore"]
        )
    ]
)
