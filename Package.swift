// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeywordOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KeywordOS",
            targets: ["KeywordOS"]
        )
    ],
    targets: [
        .target(
            name: "KeywordOS",
            linkerSettings: [
                .linkedFramework("AdServices", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "KeywordOSTests",
            dependencies: ["KeywordOS"]
        )
    ]
)
