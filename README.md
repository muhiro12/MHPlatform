# MHKit

MHKit is a Swift package workspace for shared app logic extracted from real usage in Incomes and Cookle. The current v1 baseline focuses on deep-link handling, deterministic notification planning, post-mutation side-effect orchestration, and persistence maintenance primitives.

Minimum supported platforms:
- iOS 18.0+
- macOS 15.0+

## MHDeepLinking

`MHDeepLinking` handles route URL building, parsing, and pending-route handoff without owning app-specific route enums.

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

`MHNotificationPayloads` provides routing-focused payload/action/userInfo models and resolution utilities.

```swift
import MHNotificationPayloads

let payload = MHNotificationPayload(
    routes: .init(
        defaultRouteURL: URL(string: "myapp://item?id=rent"),
        fallbackRouteURL: URL(string: "myapp://month?year=2026&month=1"),
        actionRouteURLs: ["view-month": URL(string: "myapp://month?year=2026&month=1")!]
    )
)
```

## MHMutationFlow

`MHMutationFlow` runs a mutation with retry, cancellation, and ordered post-success side effects.

```swift
import MHMutationFlow

let outcome = await MHMutationRunner.run(
    operation: { "saved" },
    retryPolicy: .default,
    afterSuccess: [.init(name: "syncNotifications") {}]
)
```

## MHRouteExecution

`MHRouteExecution` coordinates route handling with readiness checks and a latest-wins pending route queue.

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
    isReady: { hasLoadedInitialState },
    executor: executor
)

let resolution = try await coordinator.handle(.settings)
```

## MHPersistenceMaintenance

`MHPersistenceMaintenance` provides store-file migration helpers and ordered destructive reset orchestration.

```swift
import MHPersistenceMaintenance

let plan = MHStoreMigrationPlan(
    legacyStoreURL: legacyURL,
    currentStoreURL: currentURL
)
let migrationResult = try MHStoreMigrator.migrateIfNeeded(plan: plan)

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

```swift
import MHPreferences

let store = MHPreferenceStore()
let key = MHBoolPreferenceKey("notifications.enabled", default: true)
let isEnabled = store.bool(for: key)
store.set(false, for: key)
```

## Example App

`MHKitExample` demonstrates all seven modules with app-local sample data in `Example/`. It does not import any domain types from Incomes or Cookle.
