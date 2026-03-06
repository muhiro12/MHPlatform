# MHPlatform

MHPlatform is an internal app platform foundation delivered as a Swift package workspace for shared infrastructure extracted from real usage in Incomes and Cookle. The current v1 baseline focuses on deep-link handling, deterministic notification planning, post-mutation side-effect orchestration, and persistence maintenance primitives.

Minimum supported platforms:
- iOS 18.0+
- macOS 15.0+

## Documentation Map

- [North Star](Designs/Architecture/north-star.md)
- [Integration Contracts](Designs/Architecture/integration-contracts.md)
- [Integration Cookbook](Designs/Architecture/integration-cookbook.md)
- [Architecture](Designs/Architecture/architecture.md)

## MHDeepLinking

`MHDeepLinking` handles route URL building, parsing, and pending-route handoff without owning app-specific route enums.

Integration contract:
[`MHDeepLinking`](Designs/Architecture/integration-contracts.md#mhdeeplinking)

```swift
import MHDeepLinking

let codec = MHDeepLinkCodec<MyRoute>(
    configuration: .init(
        customScheme: "myapp",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: ["example.com"],
        universalLinkPathPrefix: "MyApp",
        preferredTransport: .customScheme
    )
)
```

## MHNotificationPlans

`MHNotificationPlans` builds deterministic reminder and suggestion schedules without depending on `UserNotifications`.

Integration contract:
[`MHNotificationPlans`](Designs/Architecture/integration-contracts.md#mhnotificationplans)

```swift
import MHNotificationPlans

let deliveryTime = MHNotificationTime(hour: 20, minute: 0)!
let policy = MHReminderPolicy(
    isEnabled: true,
    minimumAmount: 500,
    daysBeforeDueDate: 3,
    deliveryTime: deliveryTime,
    identifierPrefix: "upcoming-payment:"
)
```

## MHNotificationPayloads

`MHNotificationPayloads` provides routing-focused payload/action/userInfo models, response route resolution, and `UNUserNotificationCenter` orchestration helpers.

Integration contract:
[`MHNotificationPayloads`](Designs/Architecture/integration-contracts.md#mhnotificationpayloads)

```swift
import MHNotificationPayloads
import UserNotifications

let payload = MHNotificationPayload(
    routes: .init(
        defaultRouteURL: URL(string: "myapp://item?id=rent"),
        fallbackRouteURL: URL(string: "myapp://month?year=2026&month=1"),
        actionRouteURLs: ["view-month": URL(string: "myapp://month?year=2026&month=1")!]
    )
)

let status = await MHNotificationOrchestrator.requestAuthorizationIfNeeded(
    center: UNUserNotificationCenter.current(),
    options: [.alert, .sound, .providesAppNotificationSettings]
)
let syncResult = await MHNotificationOrchestrator.replaceManagedPendingRequests(
    center: UNUserNotificationCenter.current(),
    requests: requestsToSchedule,
    isManagedIdentifier: { identifier in
        identifier.hasPrefix("upcoming-payment:")
    }
)
```

## MHMutationFlow

`MHMutationFlow` runs a mutation with retry, cancellation, and ordered post-success side effects.

Integration contract:
[`MHMutationFlow`](Designs/Architecture/integration-contracts.md#mhmutationflow)

```swift
import MHMutationFlow

let mutation = MHMutation<String>(
    name: "save-item",
    operation: { "saved" }
)

let outcome = await MHMutationRunner.run(
    mutation: mutation,
    retryPolicy: .default,
    afterSuccess: [.init(name: "syncNotifications") {}]
)
```

## MHRouteExecution

`MHRouteExecution` coordinates route handling with readiness checks and a latest-wins pending route queue.

Integration contract:
[`MHRouteExecution`](Designs/Architecture/integration-contracts.md#mhrouteexecution)

```swift
import MHRouteExecution

let executor = MHRouteExecutor<AppRoute, AppRouteOutcome>(
    resolve: { route in
        try await resolveOutcome(for: route)
    },
    apply: { outcome in
        try await applyOutcome(outcome)
    }
)
let coordinator = MHRouteCoordinator(
    initialReadiness: false,
    executor: executor
)
await coordinator.setReadiness(hasLoadedInitialState)

let outcome = try await coordinator.submit(.settings)
```

## MHPersistenceMaintenance

`MHPersistenceMaintenance` provides store-file migration helpers and ordered destructive reset orchestration.

Integration contract:
[`MHPersistenceMaintenance`](Designs/Architecture/integration-contracts.md#mhpersistencemaintenance)

```swift
import MHPersistenceMaintenance

let plan = MHStoreMigrationPlan(
    legacyStoreURL: legacyURL,
    currentStoreURL: currentURL
)
let migrationOutcome = try MHStoreMigrator.migrateIfNeeded(plan: plan)

let resetOutcome = await MHDestructiveResetService.run(
    steps: [
        .init(name: "deleteAll") {
            try await deleteAllData()
        }
    ]
)
```

## MHPreferences

`MHPreferences` provides typed preference keys with `UserDefaults` and `AppStorage` bridges.

Integration contract:
[`MHPreferences`](Designs/Architecture/integration-contracts.md#mhpreferences)

```swift
import MHPreferences

let store = MHPreferenceStore()
let key = MHBoolPreferenceKey(
    namespace: "app.preferences",
    name: "notifications.enabled",
    default: true
)
let isEnabled = store.bool(for: key)
store.set(false, for: key)
```

## MHReviewPolicy

`MHReviewPolicy` provides review-request lottery policy and a high-level requester with platform-aware fallback behavior.

Integration contract:
[`MHReviewPolicy`](Designs/Architecture/integration-contracts.md#mhreviewpolicy)

```swift
import MHReviewPolicy

let policy = MHReviewPolicy(
    lotteryMaxExclusive: 10,
    requestDelay: .seconds(2)
)

let outcome = await MHReviewRequester.requestIfNeeded(policy: policy)
```

## Example App

`MHPlatformExample` demonstrates all eight modules with app-local sample data in `Example/`.

It includes cross-module demos for:

- DeepLinking + RouteExecution pipeline
- NotificationPlans + NotificationPayloads pipeline
- MutationOutcome-driven ReviewPolicy trigger
