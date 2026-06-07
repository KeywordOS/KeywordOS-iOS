// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeywordOSSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KeywordOSSDK",
            targets: ["KeywordOSSDK"]
        )
    ],
    targets: [
        .target(
            name: "KeywordOSSDK"
        ),
        .testTarget(
            name: "KeywordOSSDKTests",
            dependencies: ["KeywordOSSDK"]
        )
    ]
)
