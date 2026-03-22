// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "OptionalShellConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "OptionalShellConsumer",
            targets: ["OptionalShellConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "OptionalShellConsumer",
            dependencies: [
                .product(
                    name: "MHMutationFlow",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHReviewPolicy",
                    package: "MHPlatform"
                )
            ]
        ),
        .testTarget(
            name: "OptionalShellConsumerTests",
            dependencies: ["OptionalShellConsumer"]
        )
    ]
)

var package: Package {
    kPackage
}
