// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "RuntimeOnlyConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "RuntimeOnlyConsumer",
            targets: ["RuntimeOnlyConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "RuntimeOnlyConsumer",
            dependencies: [
                .product(
                    name: "MHAppRuntime",
                    package: "MHPlatform"
                )
            ]
        ),
        .testTarget(
            name: "RuntimeOnlyConsumerTests",
            dependencies: ["RuntimeOnlyConsumer"]
        )
    ]
)

var package: Package {
    kPackage
}
