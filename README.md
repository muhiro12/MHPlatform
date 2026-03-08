# MHPlatform

MHPlatform is an internal app platform foundation delivered as a Swift package
workspace for shared infrastructure extracted from real usage in Incomes and
Cookle. It ships both an umbrella `MHPlatform` product for app-side
convenience and granular module products for narrower adoption. The current v1
baseline focuses on runtime startup, deep-link handling, route execution,
deterministic notification planning, post-mutation side-effect orchestration,
logging, preferences, and persistence maintenance primitives.

Minimum supported platforms:
- iOS 18.0+
- macOS 15.0+

## Documentation Map

- [North Star](Designs/Architecture/north-star.md)
- [Integration Contracts](Designs/Architecture/integration-contracts.md)
- [Integration Cookbook](Designs/Architecture/integration-cookbook.md)
- [Architecture](Designs/Architecture/architecture.md)
- [Runtime-start Design](Designs/Architecture/runtime-start.md)

## Adoption

MHPlatform supports two integration styles:

- Use the umbrella `MHPlatform` product for app adoption convenience.
- Use individual module products when the app wants a narrower dependency set.

Umbrella adoption:

```swift
.product(name: "MHPlatform", package: "MHPlatform")
```

```swift
import MHPlatform

let store = MHPreferenceStore()
let policy = MHReviewPolicy(
    lotteryMaxExclusive: 10,
    requestDelay: .seconds(2)
)
```

The umbrella module is intentionally thin and re-exports the common public
modules with `@_exported import`.

Granular adoption:

```swift
.product(name: "MHDeepLinking", package: "MHPlatform")
.product(name: "MHRouteExecution", package: "MHPlatform")
```

```swift
import MHDeepLinking
import MHRouteExecution
```

## Current Adoption Snapshot

- Incomes and Cookle currently adopt MHPlatform primarily through the umbrella
  `MHPlatform` product.
- `MHAppRuntime` is the main shared runtime-start surface already used in both
  apps for startup, premium/ad availability state, and runtime-owned views.
- `MHReviewPolicy` is already shared, but the surrounding workflow triggers stay
  app-specific.
- `MHRouteExecution` now provides both the low-level coordinator/executor
  primitives and the higher-level `MHRouteLifecycle` shell. Both apps already
  use the lifecycle helper while keeping route enums, parsing, and apply logic
  app-owned.
- Domain mutation result models, follow-up metadata, and concrete side effects
  still belong to each app. `MHMutationFlow` now provides both
  `MHMutationAdapter` and the higher-level `MHMutationWorkflow` shell so apps
  can converge on a shared workflow shape without standardizing those
  app-specific schemas.
- Recent MHPlatform-first additions focus on thinner app integration:
  `MHRouteLifecycle`, `MHRouteExecution` identity helpers, lifecycle
  deep-link handoff helpers, codec-backed deep-link inbox/store/observable
  inbox helpers, `MHLoggerFactory`, `MHMutationAdapter` composition, and
  `MHMutationWorkflow`. These reduce app-side boilerplate without moving
  route enums, effect models, or concrete side effects into MHPlatform.

## MHAppRuntime

`MHAppRuntime` provides the current shared runtime-start surface for app startup
side effects and shared infrastructure state. It is already adopted by both
Incomes and Cookle via the umbrella `MHPlatform` product. `MHAppRuntimeLifecycle`
now lets apps move ordered startup and foreground wiring into a package-owned
shell instead of keeping repeated `.task` and `scenePhase` coordination inline.

Integration contract:
[`MHAppRuntime`](Designs/Architecture/integration-contracts.md#mhappruntime)

```swift
import MHAppRuntime

let runtime = MHAppRuntime(
    configuration: .init(
        subscriptionProductIDs: ["com.example.app.premium.monthly"],
        subscriptionGroupID: "12345678",
        nativeAdUnitID: "ca-app-pub-xxxxxxxx/yyyyyyyy",
        preferencesSuiteName: "group.com.example.app",
        showsLicenses: true
    )
)

ContentView()
    .mhAppRuntimeLifecycle(
        runtime: runtime,
        plan: .init(
            startupTasks: [
                .init(name: "loadConfig") {
                    await configurationService.load()
                }
            ],
            activeTasks: [
                .init(name: "refreshNotifications") {
                    await notificationService.update()
                }
            ],
            skipFirstActivePhase: true
        )
    )
```

## MHDeepLinking

`MHDeepLinking` handles route URL building, parsing, and pending-route handoff
without owning app-specific route enums. Inbox, observable inbox, and store
helpers can round-trip app-owned routes through a codec while keeping the
stored payload as a `URL`. `MHDeepLinkSourceChain` lets apps combine intent,
notification, and in-memory handoff slots into a single ordered source.

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
let routeInbox = MHObservableDeepLinkInbox()
let notificationInbox = MHDeepLinkInbox()
let intentStore = MHDeepLinkStore(
    userDefaults: .standard,
    key: "pendingIntentRouteURL"
)
let handoffSources = MHDeepLinkSourceChain(
    intentStore,
    notificationInbox
)

await notificationInbox.ingest(.settings, using: codec)
let forwardedURL = await handoffSources.forwardLatestURL(to: routeInbox)
let pendingRoute = await routeInbox.consumeLatest(using: codec)
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
import MHDeepLinking
import MHNotificationPayloads
import UserNotifications

let payload = MHNotificationPayload(
    routes: .init(
        defaultRouteURL: URL(string: "myapp://item?id=rent"),
        fallbackRouteURL: URL(string: "myapp://month?year=2026&month=1"),
        actionRouteURLs: ["view-month": URL(string: "myapp://month?year=2026&month=1")!]
    )
)
let inbox = MHDeepLinkInbox()

let status = await MHNotificationOrchestrator.requestAuthorizationIfNeeded(
    center: UNUserNotificationCenter.current(),
    options: [.alert, .sound, .providesAppNotificationSettings]
)
let syncResult = await MHNotificationOrchestrator.replaceManagedPendingRequests(
    center: UNUserNotificationCenter.current(),
    requests: requestsToSchedule,
    matcher: .init(prefixes: ["upcoming-payment:"])
)
let deliveryOutcome = await MHNotificationOrchestrator.deliverRouteURL(
    payload: payload,
    response: .init(
        actionIdentifier: UNNotificationDefaultActionIdentifier
    ),
    destination: inbox
)
```

## MHMutationFlow

`MHMutationFlow` supports two adoption levels. Reach for
`MHMutationWorkflow` when the app wants a default throwing shell with ordered
follow-up steps. Drop to `MHMutationRunner` directly only when the app needs
explicit retry, cancellation, or event streaming control.

`MHMutationAdapter` lets an app map its own success value metadata or effect
hints into ordered steps without introducing a shared cross-app mutation
outcome model. Adapters can also be composed to keep fixed and value-derived
follow-up steps explicit.

Integration contract:
[`MHMutationFlow`](Designs/Architecture/integration-contracts.md#mhmutationflow)

```swift
import MHMutationFlow

struct SaveItemFollowUp: Sendable {
    let shouldReloadWidgets: Bool
    let shouldSyncNotifications: Bool
}

struct SaveItemResult: Sendable {
    let value: String
    let followUp: SaveItemFollowUp
}

let adapter = MHMutationAdapter<SaveItemFollowUp>.build { followUp in
    if followUp.shouldReloadWidgets {
        MHMutationStep.mainActor(name: "reloadWidgets") {
            reloadWidgets()
        }
    }

    if followUp.shouldSyncNotifications {
        MHMutationStep.mainActor(name: "syncNotifications") {
            await syncNotifications()
        }
    }
}

let result = try await MHMutationWorkflow.runThrowing(
    name: "save-item",
    operation: {
        .init(
            value: "saved",
            followUp: .init(
                shouldReloadWidgets: true,
                shouldSyncNotifications: true
            )
        )
    },
    adapter: adapter,
    adapterValue: \.followUp,
    resultValue: \.value
)
```

The lower-level `MHMutationRunner` remains available when the app needs custom
retry policy, cancellation handles, or observable event streams.

## MHRouteExecution

`MHRouteExecution` supports two adoption levels. Reach for
`MHRouteLifecycle` when the app wants a logger-backed helper around parsed
URLs, pending-source drain, readiness gating, and queued-route replay. Drop to
`MHRouteCoordinator` directly only when the app needs explicit resolve/apply
separation or direct pending-queue introspection.

Integration contract:
[`MHRouteExecution`](Designs/Architecture/integration-contracts.md#mhrouteexecution)

```swift
import MHDeepLinking
import MHLogging
import MHRouteExecution

let codec = MHDeepLinkCodec<AppRoute>(
    configuration: .init(
        customScheme: "myapp",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: ["example.com"],
        universalLinkPathPrefix: "MyApp",
        preferredTransport: .customScheme
    )
)
let routeInbox = MHObservableDeepLinkInbox()
let notificationInbox = MHDeepLinkInbox()
let logger = MHLoggerFactory.osLogDefault.logger(
    category: "route",
    source: #fileID
)
let routeLifecycle = MHRouteLifecycle<AppRoute>(
    logger: logger,
    initialReadiness: false,
    isDuplicate: ==
)
await routeLifecycle.setReadiness(hasLoadedInitialState)

_ = try await routeLifecycle.submitLatest(
    from: routeInbox,
    notificationInbox,
    using: codec,
    applyOnMainActor: { route in
        try await applyRoute(route)
    }
)
```

Use `MHObservableDeepLinkInbox` when SwiftUI needs to observe the pending URL,
swap in `MHDeepLinkInbox` for actor-only handoff, and use `MHDeepLinkStore`
when the pending URL must survive process restarts. When multiple sources can
race to provide the next URL, pass them directly to `submitLatest(from:...)`
in priority order or build an `MHDeepLinkSourceChain` first when you want to
reuse that ordering elsewhere.

The lower-level `MHRouteCoordinator` and identity-route apply path remain
available for flows that need a custom resolve/apply split or direct pending
queue inspection.

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

## MHLogging

`MHLogging` provides a structured logging surface with in-memory query support,
JSONL persistence, and reusable console UI. `MHLoggerFactory` is a thin helper
for app-owned logger setup; it does not move runtime wiring or policy decisions
into MHPlatform.

Integration contract:
[`MHLogging`](Designs/Architecture/integration-contracts.md#mhlogging)

```swift
import MHLogging

let policy = MHLogPolicy.default
let jsonSink = MHJSONLLogSink(
    fileURL: FileManager.default.temporaryDirectory
        .appendingPathComponent("app.logs.jsonl"),
    maximumFileSizeBytes: policy.maximumDiskBytes
)
let loggerFactory = MHLoggerFactory(
    policy: policy,
    subsystem: "com.example.app",
    sinks: [
        MHOSLogSink(),
        jsonSink
    ]
)
let logger = loggerFactory.logger(
    category: "startup",
    source: #fileID
)
logger.info("App started")
```

## Example App

`MHPlatformExample` demonstrates all modules with app-local sample data in `Example/`.

It includes cross-module demos for:

- DeepLinking inbox + RouteLifecycle pipeline
- RouteExecution low-level coordinator apply path
- NotificationPlans + NotificationPayloads pipeline
- MutationWorkflow-driven ReviewPolicy trigger
- Structured logging + JSONL analysis workflow
- MutationFlow adapter composition with ordered follow-up steps
