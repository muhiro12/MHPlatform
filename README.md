# MHPlatform

MHPlatform is an internal app platform foundation delivered as a Swift package
workspace for shared infrastructure extracted from real usage in Incomes and
Cookle. It ships a full app umbrella `MHPlatform`, a shared-package umbrella
`MHPlatformCore`, and granular module products for narrower adoption. The
current v1 baseline focuses on runtime startup, deep-link handling, route
execution, deterministic notification planning, post-mutation side-effect
orchestration, logging, preferences, and persistence maintenance primitives.

Minimum supported platforms:
- iOS 18.0+
- macOS 15.0+
- watchOS 11.0+

## Documentation Map

- [Architecture Guide](Designs/Architecture/ARCHITECTURE_GUIDE.md)
- [North Star](Designs/Architecture/north-star.md)
- [Integration Contracts](Designs/Architecture/integration-contracts.md)
- [Integration Cookbook](Designs/Architecture/integration-cookbook.md)
- [Minimal App Setup](Designs/Architecture/minimal-app-setup.md)
- [Migrating to Current Shells](Designs/Architecture/migrating-to-current-shells.md)
- [Architecture](Designs/Architecture/architecture.md)
- [Runtime-start Design](Designs/Architecture/runtime-start.md)
- [Design Decisions](Designs/Decisions/README.md)
- [Platform Status](Designs/Overviews/platform-status.md)
- [Build Notes](Designs/Overviews/build-notes.md)
- [Backlog](Designs/Overviews/backlog.md)

## Directory Conventions

- Keep the top-level package layout stable: `Sources/`, `Tests/`, `Example/`,
  `Designs/`, and `ci_scripts/`.
- Organize `Sources/<Target>/` with shallow responsibility-based folders such
  as `Configuration`, `Runtime`, `Routing`, `Workflow`, `Store`, and `SwiftUI`.
- Keep small targets flat when subdirectories do not improve discoverability.
- Put test-only helpers under `Tests/<Target>/Support/`.
- Keep the example app shell in `Example/MHPlatformExample/App/` and place
  module demos under `Example/MHPlatformExample/Demos/<Area>/`.

## Adoption

MHPlatform supports four main integration styles:

- Use `MHPlatform` for app targets that want the full umbrella, including the
  `MHAppRuntime` default adapter path.
- Use `MHPlatformCore` for shared packages, including watch-capable packages,
  that want a narrower umbrella without `MHAppRuntime` or third-party runtime
  adapters.
- Use individual module products when the consumer wants a narrower dependency
  set than either umbrella.
- Use `MHAppRuntimeCore` directly when the app only needs runtime/bootstrap
  mechanics and should avoid the heavier default StoreKit, ads, or license
  dependencies.

Full app umbrella adoption:

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

`MHPlatform` remains an aggregation target with no independent runtime logic.
It re-exports `MHPlatformCore`, `MHAppRuntime`, `MHMutationFlow`, and
`MHReviewPolicy`. Because `MHAppRuntime` keeps the default StoreKit, ads, and
license integrations, adopting `MHPlatform` also resolves those implementation
dependencies for app targets.

Shared package umbrella adoption:

```swift
.product(name: "MHPlatformCore", package: "MHPlatform")
```

```swift
import MHPlatformCore

let store = MHPreferenceStore()
let logger = MHLoggerFactory.osLogDefault.logger(
    category: "shared",
    source: #fileID
)
```

`MHPlatformCore` is the recommended umbrella for shared packages. It re-exports
`MHDeepLinking`, `MHLogging`, `MHNotificationPlans`, `MHNotificationPayloads`,
`MHRouteExecution`, `MHPersistenceMaintenance`, and `MHPreferences` without
pulling in `MHAppRuntime` or third-party runtime adapters.

Granular adoption:

```swift
.product(name: "MHDeepLinking", package: "MHPlatform")
.product(name: "MHRouteExecution", package: "MHPlatform")
```

```swift
import MHDeepLinking
import MHRouteExecution
```

Direct third-party dependency rule:

- `MHPlatform` does not re-export third-party symbols from `StoreKitWrapper`,
  `GoogleMobileAdsWrapper`, or `LicenseList`.
- If consumer code uses those APIs directly, add the third-party package as a
  direct dependency and `import` that module explicitly.

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

Recommended starting paths:

- shared package umbrella: `MHPlatformCore`
- app root assembly: `MHAppRuntimeBootstrap`
- runtime-only product: `MHAppRuntimeCore`
- opt-in runtime defaults: `MHAppRuntimeDefaults`, `MHAppRuntimeAds`,
  `MHAppRuntimeLicenses`
- preview/test runtime injection: `View.mhAppRuntimeEnvironment(_:)`
- route root wiring: `MHAppRoutePipeline`
- route handoff into app-owned navigation state: `MHObservableRouteInbox`
- review trigger wiring: `MHReviewFlow`
- fixed adapter follow-up from mutations: `MHMutationWorkflow.runThrowing(..., adapterValue:)`

## MHAppRuntime

`MHAppRuntimeBootstrap` is the recommended runtime-start entry point for new
apps. It assembles `MHAppRuntime`, `MHAppRuntimeLifecyclePlan`, optional route
pipeline root integration, and SwiftUI runtime environment injection into a
single package-owned shell. Lower-level `MHAppRuntime`, `MHAppRuntimeLifecycle`,
and `MHAppRoutePipeline` remain available when an app needs custom integration
or non-SwiftUI control.

Use `MHAppRuntime` when the app wants the default StoreKit, ads, and runtime-
owned license integrations. Use `MHAppRuntimeCore` when the app only needs
runtime/bootstrap/lifecycle/route mechanics without those external
dependencies. When the app wants only some package-owned defaults, compose the
core initializer with `MHAppRuntimeDefaultsBundle`, `MHAppRuntimeAdsBundle`,
and `MHAppRuntimeLicensesBundle` from the split bundle products.

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
When the app wants latest-route handoff before mutating navigation state, pair
`MHAppRoutePipeline` with `MHObservableRouteInbox<Route>` and
`View.mhRouteHandler(_:apply:)`. Observe `routePipeline.lastParseFailureURL`
when invalid deep links should present app-owned error UI.
Runtime-bootstrap-only adoption is a first-class path. Apps that do not use
route, review, or mutation shells can stop at `MHAppRuntimeBootstrap` and
`View.mhAppRuntimeEnvironment(_:)` without pulling additional workflow APIs
into their root.

For previews and tests that only need runtime injection, prefer:

```swift
let bootstrap = MHAppRuntimeBootstrap(
    runtimeOnlyConfiguration: .init(
        preferencesSuiteName: "group.com.example.preview"
    )
)

ContentView()
    .mhAppRuntimeEnvironment(bootstrap)
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
follow-up steps explicit. For conditionally appending review, async, or
main-actor work from app-owned effect flags, prefer
`MHMutationAdapter.build { ... }` plus `MHMutationStepListBuilder` rather than
adding another package-owned builder layer.

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
    adapterValue: .init(
        shouldReloadWidgets: true,
        shouldSyncNotifications: true
    ),
    configuration: .init(
        retryPolicy: .default
    )
)
```

The lower-level `MHMutationRunner` remains available when the app needs
observable event streams or direct run-handle ownership. Retry policy,
cancellation handles, and operation failure formatting now fit in
`MHMutationWorkflowConfiguration`. Use `adapterValue:` when the successful
operation value should be returned unchanged and only the adapter input is
fixed. Projection strategies keep adapter input and result shaping explicit
with `.identity`, `.fixedAdapterValue(_:)`, `.keyPaths(adapterValue:resultValue:)`, and
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
Use `MHObservableRouteInbox<Route>` when parsed routes should be handed to an
app-owned navigation model through a replace-latest observable slot.

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

Prefer `reviewFlow.step(name:)` for successful mutation follow-up and
`reviewFlow.task(name:)` for lifecycle or activation-based prompts. Keep the
mapping from app-specific success effects to "should request review" decisions
in the app layer.

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

## Requirements

- Xcode 16 or later with the iOS 18, macOS 15, and watchOS 11 SDKs installed
- `swiftlint` for repository verify and strict lint runs
- `pre-commit` for the full `verify.sh` entrypoint

## Setup

1. Clone the repository and open the project directory.
2. Open `Package.swift` in Xcode if you want package browsing and test support.
3. Open `Example/MHPlatformExample.xcodeproj` if you want to run the demo app shell.
4. Use the helper scripts in `ci_scripts/tasks/` for repeatable local verification.

## Build and Test

Use the helper scripts in `ci_scripts/tasks/` as needed. For full local verification:

```sh
bash ci_scripts/tasks/verify.sh
```

If you only need required checks based on local package changes:

```sh
bash ci_scripts/tasks/run_required_builds.sh
```

If you only need the package and example app build:

```sh
bash ci_scripts/tasks/build_app.sh
```

If you only need Swift package tests:

```sh
bash ci_scripts/tasks/test_shared_library.sh
```

If you only need pre-commit hooks:

```sh
bash ci_scripts/tasks/pre_commit.sh
```

## CI Artifact Layout

CI helper scripts write generated artifacts under `.build/ci/`.
Run-scoped outputs are stored in `.build/ci/runs/<RUN_ID>/` (`summary.md`,
`commands.txt`, `meta.json`, `logs/`, `results/`, `work/`), while shared
caches and build state live in `.build/ci/shared/` (`cache/`, `DerivedData/`,
`tmp/`, `home/`).
