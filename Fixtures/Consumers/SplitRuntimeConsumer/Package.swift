// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "SplitRuntimeConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SplitRuntimeConsumer",
            targets: ["SplitRuntimeConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "SplitRuntimeConsumer",
            dependencies: [
                .product(
                    name: "MHAppRuntime",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHAppRuntimeAds",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHAppRuntimeDefaults",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHAppRuntimeLicenses",
                    package: "MHPlatform"
                )
            ]
        ),
        .testTarget(
            name: "SplitRuntimeConsumerTests",
            dependencies: ["SplitRuntimeConsumer"]
        )
    ]
)

var package: Package {
    kPackage
}
