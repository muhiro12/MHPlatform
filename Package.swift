// swift-tools-version: 6.2

import PackageDescription

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
            name: "MHPreferencesUI",
            targets: ["MHPreferencesUI"]
        ),
        .library(
            name: "MHLogging",
            targets: ["MHLogging"]
        ),
        .library(
            name: "MHLoggingUI",
            targets: ["MHLoggingUI"]
        ),
        .library(
            name: "MHMutationFlow",
            targets: ["MHMutationFlow"]
        ),
        .library(
            name: "MHMutationLogging",
            targets: ["MHMutationLogging"]
        ),
        .library(
            name: "MHReviewPolicy",
            targets: ["MHReviewPolicy"]
        ),
        .library(
            name: "MHReviewRequesting",
            targets: ["MHReviewRequesting"]
        ),
        .library(
            name: "MHReviewFlow",
            targets: ["MHReviewFlow"]
        ),

        // Test support.
        .library(
            name: "MHPlatformTesting",
            targets: ["MHPlatformTesting"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/muhiro12/StoreKitWrapper",
            "1.1.0"..<"2.0.0"
        ),
        .package(
            url: "https://github.com/muhiro12/GoogleMobileAdsWrapper",
            "1.3.0"..<"2.0.0"
        ),
        .package(
            url: "https://github.com/cybozu/LicenseList",
            "2.0.0"..<"3.0.0"
        ),

        // Tooling-only command plugin used by retained repository rule scripts.
        .package(
            url: "https://github.com/SimplyDanny/SwiftLintPlugins",
            "0.64.0"..<"1.0.0"
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
                "MHLoggingUI",
                "MHMutationFlow",
                "MHMutationLogging",
                "MHPlatformCore",
                "MHPreferencesUI",
                "MHReviewFlow",
                "MHReviewPolicy",
                "MHReviewRequesting"
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
            name: "MHDeepLinking",
            dependencies: ["MHPreferences"]
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
            name: "MHMutationLogging",
            dependencies: [
                "MHLogging",
                "MHMutationFlow"
            ]
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
            name: "MHPreferencesUI",
            dependencies: ["MHPreferences"]
        ),

        // Advanced review, workflow, and logging surfaces.
        .target(
            name: "MHReviewPolicy"
        ),
        .target(
            name: "MHReviewRequesting",
            dependencies: [
                "MHLogging",
                "MHReviewPolicy"
            ]
        ),
        .target(
            name: "MHReviewFlow",
            dependencies: [
                "MHAppRuntime",
                "MHLogging",
                "MHMutationFlow",
                "MHReviewPolicy",
                "MHReviewRequesting"
            ]
        ),
        .target(
            name: "MHLogging",
            dependencies: ["MHPreferences"]
        ),
        .target(
            name: "MHLoggingUI",
            dependencies: ["MHLogging"]
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
        .target(
            name: "MHPreferencesTestSupport",
            dependencies: ["MHPreferences"],
            path: "Tests/MHPreferencesTestSupport"
        ),
        .target(
            name: "MHReviewTestSupport",
            path: "Tests/MHReviewTestSupport"
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
            dependencies: [
                "MHDeepLinking",
                "MHPreferences"
            ]
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
            name: "MHMutationLoggingTests",
            dependencies: [
                "MHLogging",
                "MHMutationFlow",
                "MHMutationLogging"
            ]
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
            dependencies: [
                "MHPreferences",
                "MHPreferencesTestSupport"
            ]
        ),
        .testTarget(
            name: "MHPreferencesUITests",
            dependencies: [
                "MHPreferences",
                "MHPreferencesTestSupport",
                "MHPreferencesUI"
            ]
        ),
        .testTarget(
            name: "MHReviewPolicyTests",
            dependencies: ["MHReviewPolicy"]
        ),
        .testTarget(
            name: "MHReviewRequestingTests",
            dependencies: [
                "MHLogging",
                "MHReviewPolicy",
                "MHReviewRequesting",
                "MHReviewTestSupport"
            ]
        ),
        .testTarget(
            name: "MHReviewFlowTests",
            dependencies: [
                "MHAppRuntime",
                "MHLogging",
                "MHMutationFlow",
                "MHReviewFlow",
                "MHReviewPolicy",
                "MHReviewRequesting",
                "MHReviewTestSupport"
            ]
        ),
        .testTarget(
            name: "MHLoggingTests",
            dependencies: [
                "MHLogging",
                "MHPreferences",
                "MHPlatformTesting"
            ]
        ),
        .testTarget(
            name: "MHLoggingUITests",
            dependencies: [
                "MHLogging",
                "MHLoggingUI"
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
