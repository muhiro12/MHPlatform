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

Testing support:

```swift
.product(name: "MHPlatformTesting", package: "MHPlatform")
```

`MHPlatformTesting` is a separate test-support product. It provides reusable
helpers such as `MHNotificationCenterDouble`, `MHDeepLinkURLRecorder`,
`MHLogSinkRecorder`, and `MHRouteExecutionRecorder` without re-exporting them
through the umbrella `MHPlatform` module.
For a package-owned end-to-end reference, see
`Tests/MHPlatformIntegrationTests/MHPlatformIntegrationTests.swift`.

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

`MHAppRuntimeBootstrap` is the recommended runtime-start entry point for new
apps. It assembles `MHAppRuntime`, `MHAppRuntimeLifecyclePlan`, optional route
pipeline root integration, and SwiftUI runtime environment injection into a
single package-owned shell. Lower-level `MHAppRuntime`, `MHAppRuntimeLifecycle`,
and `MHAppRoutePipeline` remain available when an app needs custom integration
or non-SwiftUI control.

Integration contract:
[`MHAppRuntime`](Designs/Architecture/integration-contracts.md#mhappruntime)

```swift
import MHAppRuntime
import MHDeepLinking
import MHLogging
import MHRouteExecution

let routeCodec = MHDeepLinkCodec<AppRoute>(
    configuration: .init(
        customScheme: "myapp",
        preferredUniversalLinkHost: "example.com",
        allowedUniversalLinkHosts: ["example.com"],
        universalLinkPathPrefix: "MyApp",
        preferredTransport: .customScheme
    )
)
let routePipeline = MHAppRoutePipeline(
    routeLifecycle: MHRouteLifecycle<AppRoute>(
        logger: MHLoggerFactory.osLogDefault.logger(
            category: "route",
            source: #fileID
        ),
        initialReadiness: false,
        isDuplicate: ==
    ),
    using: routeCodec,
    pendingSources: [
        intentStore,
        notificationInbox
    ]
) { route in
    try await applyRoute(route)
}
let bootstrap = MHAppRuntimeBootstrap(
    configuration: .init(
        subscriptionProductIDs: ["com.example.app.premium.monthly"],
        subscriptionGroupID: "12345678",
        nativeAdUnitID: "ca-app-pub-xxxxxxxx/yyyyyyyy",
        preferencesSuiteName: "group.com.example.app",
        showsLicenses: true
    ),
    lifecyclePlan: .init(
        commonTasks: [
            .init(name: "syncSubscriptionState") {
                syncSubscriptionStateIfNeeded()
            }
        ],
        startupTasks: [
            .init(name: "loadConfig") {
                await configurationService.load()
            }
        ],
        activeTasks: [
            routePipeline.task(name: "synchronizePendingRoutes")
        ],
        skipFirstActivePhase: true
    ),
    routePipeline: routePipeline
)

ContentView()
    .mhAppRuntimeBootstrap(bootstrap)
```

Use `bootstrap.routeInbox` when app-owned services need a package-owned pending
route destination, such as notification or App Intent handoff adapters.

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
        "saved"
    },
    adapter: adapter,
    projection: .fixedAdapterValue(
        .init(
            shouldReloadWidgets: true,
            shouldSyncNotifications: true
        )
    ),
    configuration: .init(
        retryPolicy: .default
    )
)
```

The lower-level `MHMutationRunner` remains available when the app needs
observable event streams or direct run-handle ownership. Retry policy,
cancellation handles, and operation failure formatting now fit in
`MHMutationWorkflowConfiguration`. Projection strategies keep adapter input
and result shaping explicit with `.identity`, `.fixedAdapterValue(_:)`,
`.keyPaths(adapterValue:resultValue:)`, and
`.closures(afterSuccess:returning:)`. When an app already owns a combined
success carrier, `MHMutationProjection` still works with a `.keyPaths`
strategy. Add `onEvent:` to `MHMutationRunner` or
`MHMutationWorkflow.runThrowing` when the app wants ordered mutation
callbacks without storing an `AsyncStream`.

## MHRouteExecution

`MHRouteExecution` supports two adoption levels. Reach for
`MHRouteLifecycle` when the app wants a logger-backed helper around parsed
URLs, pending-source drain, readiness gating, and queued-route replay. Drop to
`MHRouteCoordinator` directly only when the app needs explicit resolve/apply
separation or direct pending-queue introspection.

When the app also wants package-owned root-view wiring for ordered source
composition, URL ingestion, and activation/drain coordination, layer
`MHAppRoutePipeline` on top from `MHAppRuntime`.

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

`MHReviewPolicy` provides review-request lottery policy plus a higher-level flow shell with runtime and mutation wiring.

Integration contract:
[`MHReviewPolicy`](Designs/Architecture/integration-contracts.md#mhreviewpolicy)

```swift
import MHReviewPolicy

let policy = MHReviewPolicy(
    lotteryMaxExclusive: 10,
    requestDelay: .seconds(2)
)

let reviewFlow = MHReviewFlow(policy: policy)
let outcome = await reviewFlow.requestIfNeeded()
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
