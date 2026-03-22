// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "DefaultRuntimeConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "DefaultRuntimeConsumer",
            targets: ["DefaultRuntimeConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "DefaultRuntimeConsumer",
            dependencies: [
                .product(
                    name: "MHAppRuntime",
                    package: "MHPlatform"
                )
            ]
        )
    ]
)

var package: Package {
    kPackage
}
