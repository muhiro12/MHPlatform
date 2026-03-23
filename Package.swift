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
        // Public app and shared-library entry points.
        .library(
            name: "MHPlatform",
            targets: ["MHPlatform"]
        ),
        .library(
            name: "MHAppRuntime",
            targets: ["MHAppRuntime"]
        ),
        .library(
            name: "MHPlatformCore",
            targets: ["MHPlatformCore"]
        ),

        // Advanced runtime composition bundles.
        .library(
            name: "MHAppRuntimeDefaults",
            targets: ["MHAppRuntimeDefaults"]
        ),
        .library(
            name: "MHAppRuntimeAds",
            targets: ["MHAppRuntimeAds"]
        ),
        .library(
            name: "MHAppRuntimeLicenses",
            targets: ["MHAppRuntimeLicenses"]
        ),

        // Advanced concrete modules and optional shells.
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
            name: "MHLogging",
            targets: ["MHLogging"]
        ),
        .library(
            name: "MHMutationFlow",
            targets: ["MHMutationFlow"]
        ),
        .library(
            name: "MHReviewPolicy",
            targets: ["MHReviewPolicy"]
        ),

        // Test support.
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
        // App-facing convenience umbrella and advanced runtime entry point.
        .target(
            name: "MHPlatform",
            dependencies: [
                "MHAppRuntime",
                "MHAppRuntimeAds",
                "MHAppRuntimeDefaults",
                "MHAppRuntimeLicenses",
                "MHMutationFlow",
                "MHPlatformCore",
                "MHReviewPolicy"
            ]
        ),
        .target(
            name: "MHPlatformCore",
            dependencies: [
                "MHDeepLinking",
                "MHLogging",
                "MHNotificationPlans",
                "MHNotificationPayloads",
                "MHRouteExecution",
                "MHPersistenceMaintenance",
                "MHPreferences"
            ]
        ),
        .target(
            name: "MHAppRuntime",
            dependencies: [
                "MHDeepLinking",
                "MHLogging",
                "MHPreferences",
                "MHRouteExecution"
            ]
        ),
        .target(
            name: "MHAppRuntimeDefaults",
            dependencies: [
                "MHAppRuntime",
                "MHPreferences",
                .product(
                    name: "StoreKitWrapper",
                    package: "StoreKitWrapper",
                    condition: .when(platforms: [.iOS, .macOS])
                )
            ]
        ),
        .target(
            name: "MHAppRuntimeAds",
            dependencies: [
                "MHAppRuntime",
                .product(
                    name: "GoogleMobileAdsWrapper",
                    package: "GoogleMobileAdsWrapper",
                    condition: .when(platforms: [.iOS])
                )
            ]
        ),
        .target(
            name: "MHAppRuntimeLicenses",
            dependencies: [
                "MHAppRuntime",
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

        // Optional workflow shells for app targets.
        .target(
            name: "MHReviewPolicy",
            dependencies: [
                "MHAppRuntime",
                "MHLogging",
                "MHMutationFlow"
            ]
        ),
        .target(
            name: "MHLogging"
        ),

        // Test support.
        .target(
            name: "MHPlatformTesting",
            dependencies: [
                "MHDeepLinking",
                "MHLogging",
                "MHNotificationPayloads"
            ]
        ),

        // Product export tests.
        .testTarget(
            name: "MHPlatformTests",
            dependencies: ["MHPlatform"]
        ),
        .testTarget(
            name: "MHPlatformCoreTests",
            dependencies: ["MHPlatformCore"]
        ),

        // Runtime and module behavior tests.
        .testTarget(
            name: "MHAppRuntimeTests",
            dependencies: [
                "MHAppRuntimeAds",
                "MHAppRuntime",
                "MHAppRuntimeDefaults",
                "MHAppRuntimeLicenses",
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
