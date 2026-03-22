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
                    name: "MHAppRuntimeCore",
                    package: "MHPlatform"
                )
            ]
        )
    ]
)

var package: Package {
    kPackage
}
