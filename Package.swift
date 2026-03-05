// swift-tools-version: 6.2

import PackageDescription

// swiftlint:disable:next prefixed_toplevel_constant
let package = Package(
    name: "MHKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
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
        )
    ],
    targets: [
        .target(
            name: "MHDeepLinking"
        ),
        .target(
            name: "MHNotificationPlans"
        ),
        .target(
            name: "MHNotificationPayloads"
        ),
        .target(
            name: "MHMutationFlow"
        ),
        .target(
            name: "MHRouteExecution"
        ),
        .target(
            name: "MHPersistenceMaintenance"
        ),
        .target(
            name: "MHPreferences"
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
            dependencies: ["MHNotificationPayloads"]
        ),
        .testTarget(
            name: "MHMutationFlowTests",
            dependencies: ["MHMutationFlow"]
        ),
        .testTarget(
            name: "MHRouteExecutionTests",
            dependencies: ["MHRouteExecution"]
        ),
        .testTarget(
            name: "MHPersistenceMaintenanceTests",
            dependencies: ["MHPersistenceMaintenance"]
        ),
        .testTarget(
            name: "MHPreferencesTests",
            dependencies: ["MHPreferences"]
        )
    ]
)
