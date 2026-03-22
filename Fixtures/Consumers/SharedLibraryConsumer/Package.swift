// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "SharedLibraryConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SharedLibraryConsumer",
            targets: ["SharedLibraryConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "SharedLibraryConsumer",
            dependencies: [
                .product(
                    name: "MHPlatformCore",
                    package: "MHPlatform"
                )
            ]
        )
    ]
)

var package: Package {
    kPackage
}
