// swift-tools-version: 6.2

import PackageDescription

// swiftlint:disable:next prefixed_toplevel_constant
let package = Package(
    name: "MHPlatform",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "MHPlatform",
            targets: ["MHPlatform"]
        ),
        .library(
            name: "MHAppRuntime",
            targets: ["MHAppRuntime"]
        ),
        .library(
            name: "MHAppRuntimeCore",
            targets: ["MHAppRuntimeCore"]
        ),
        .library(
            name: "MHDeepLinking",
            targets: ["MHDeepLinking"]
        ),
        .library(
            name: "MHNotificationPlans",
            targets: ["MHNotificationPlans"]
        ),
        .library(
            name: "MHNotificationPayloads",
            targets: ["MHNotificationPayloads"]
        ),
        .library(
            name: "MHMutationFlow",
            targets: ["MHMutationFlow"]
        ),
        .library(
            name: "MHRouteExecution",
            targets: ["MHRouteExecution"]
        ),
        .library(
            name: "MHPersistenceMaintenance",
            targets: ["MHPersistenceMaintenance"]
        ),
        .library(
            name: "MHPreferences",
            targets: ["MHPreferences"]
        ),
        .library(
            name: "MHReviewPolicy",
            targets: ["MHReviewPolicy"]
        ),
        .library(
            name: "MHLogging",
            targets: ["MHLogging"]
        ),
        .library(
            name: "MHPlatformTesting",
            targets: ["MHPlatformTesting"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/muhiro12/StoreKitWrapper.git",
            "1.1.0"..<"2.0.0"
        ),
        .package(
            url: "https://github.com/muhiro12/GoogleMobileAdsWrapper.git",
            "1.3.0"..<"2.0.0"
        ),
        .package(
            url: "https://github.com/cybozu/LicenseList.git",
            "2.0.0"..<"3.0.0"
        )
    ],
    targets: [
        .target(
            name: "MHPlatform",
            dependencies: [
                "MHAppRuntimeCore",
                "MHAppRuntime",
                "MHDeepLinking",
                "MHNotificationPlans",
                "MHNotificationPayloads",
                "MHMutationFlow",
                "MHRouteExecution",
                "MHPersistenceMaintenance",
                "MHPreferences",
                "MHReviewPolicy",
                "MHLogging"
            ]
        ),
        .target(
            name: "MHAppRuntimeCore",
            dependencies: [
                "MHDeepLinking",
                "MHLogging",
                "MHPreferences",
                "MHRouteExecution"
            ]
        ),
        .target(
            name: "MHAppRuntime",
            dependencies: [
                "MHAppRuntimeCore",
                "MHPreferences",
                .product(
                    name: "StoreKitWrapper",
                    package: "StoreKitWrapper",
                    condition: .when(platforms: [.iOS, .macOS])
                ),
                .product(
                    name: "GoogleMobileAdsWrapper",
                    package: "GoogleMobileAdsWrapper",
                    condition: .when(platforms: [.iOS])
                ),
                .product(
                    name: "LicenseList",
                    package: "LicenseList",
                    condition: .when(platforms: [.iOS])
                )
            ]
        ),
        .target(
            name: "MHDeepLinking"
        ),
        .target(
            name: "MHNotificationPlans"
        ),
        .target(
            name: "MHNotificationPayloads",
            dependencies: ["MHDeepLinking"]
        ),
        .target(
            name: "MHMutationFlow"
        ),
        .target(
            name: "MHRouteExecution",
            dependencies: [
                "MHDeepLinking",
                "MHLogging"
            ]
        ),
        .target(
            name: "MHPersistenceMaintenance"
        ),
        .target(
            name: "MHPreferences"
        ),
        .target(
            name: "MHReviewPolicy",
            dependencies: [
                "MHAppRuntimeCore",
                "MHLogging",
                "MHMutationFlow"
            ]
        ),
        .target(
            name: "MHLogging"
        ),
        .target(
            name: "MHPlatformTesting",
            dependencies: [
                "MHDeepLinking",
                "MHLogging",
                "MHNotificationPayloads"
            ]
        ),
        .testTarget(
            name: "MHPlatformTests",
            dependencies: ["MHPlatform"]
        ),
        .testTarget(
            name: "MHAppRuntimeTests",
            dependencies: [
                "MHAppRuntime",
                "MHAppRuntimeCore",
                "MHLogging",
                "MHPlatformTesting",
                "MHPreferences",
                "MHRouteExecution"
            ]
        ),
        .testTarget(
            name: "MHDeepLinkingTests",
            dependencies: ["MHDeepLinking"]
        ),
        .testTarget(
            name: "MHNotificationPlansTests",
            dependencies: ["MHNotificationPlans"]
        ),
        .testTarget(
            name: "MHNotificationPayloadsTests",
            dependencies: [
                "MHNotificationPayloads",
                "MHDeepLinking",
                "MHPlatformTesting"
            ]
        ),
        .testTarget(
            name: "MHMutationFlowTests",
            dependencies: ["MHMutationFlow"]
        ),
        .testTarget(
            name: "MHRouteExecutionTests",
            dependencies: [
                "MHDeepLinking",
                "MHRouteExecution",
                "MHLogging",
                "MHPlatformTesting"
            ]
        ),
        .testTarget(
            name: "MHPersistenceMaintenanceTests",
            dependencies: ["MHPersistenceMaintenance"]
        ),
        .testTarget(
            name: "MHPreferencesTests",
            dependencies: ["MHPreferences"]
        ),
        .testTarget(
            name: "MHReviewPolicyTests",
            dependencies: [
                "MHAppRuntime",
                "MHAppRuntimeCore",
                "MHMutationFlow",
                "MHReviewPolicy",
                "MHLogging"
            ]
        ),
        .testTarget(
            name: "MHLoggingTests",
            dependencies: [
                "MHLogging",
                "MHPlatformTesting"
            ]
        ),
        .testTarget(
            name: "MHPlatformIntegrationTests",
            dependencies: [
                "MHAppRuntime",
                "MHAppRuntimeCore",
                "MHDeepLinking",
                "MHLogging",
                "MHMutationFlow",
                "MHNotificationPayloads",
                "MHPlatformTesting",
                "MHPreferences",
                "MHRouteExecution"
            ]
        )
    ]
)
