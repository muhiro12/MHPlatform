// swift-tools-version: 6.2

import PackageDescription

let kPackage = Package(
    name: "SurfaceAdapterConsumer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SurfaceAdapterConsumer",
            targets: ["SurfaceAdapterConsumer"]
        )
    ],
    dependencies: [
        .package(path: "../../../")
    ],
    targets: [
        .target(
            name: "SurfaceAdapterConsumer",
            dependencies: [
                .product(
                    name: "MHDeepLinking",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHNotificationPayloads",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHNotificationPlans",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHPreferences",
                    package: "MHPlatform"
                ),
                .product(
                    name: "MHRouteExecution",
                    package: "MHPlatform"
                )
            ]
        ),
        .testTarget(
            name: "SurfaceAdapterConsumerTests",
            dependencies: ["SurfaceAdapterConsumer"]
        )
    ]
)

var package: Package {
    kPackage
}
