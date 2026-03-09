# MHPlatform Integration Cookbook

This cookbook focuses on composable end-to-end integration patterns.
The package-owned canonical end-to-end reference lives in
`Tests/MHPlatformIntegrationTests/MHPlatformIntegrationTests.swift`.

## Recipe 0: Minimal New App Setup

Start a brand-new app with one app-owned assembly object that owns:

- the app's navigation model
- the app's service graph
- one `MHAppRuntimeBootstrap`

Keep route meaning and navigation state in the app. Put only route mechanics in
MHPlatform.

```swift
import MHAppRuntime
import MHDeepLinking
import MHLogging
import MHRouteExecution

@MainActor
final class AppAssembly {
    let navigationModel = NavigationModel()
    let routeInbox = MHObservableRouteInbox<AppRoute>()
    let bootstrap: MHAppRuntimeBootstrap

    init(logger: MHLogger) {
        let codec = MHDeepLinkCodec<AppRoute>(configuration: configuration)
        let routePipeline = MHAppRoutePipeline(
            routeLifecycle: .init(
                logger: logger,
                initialReadiness: false,
                isDuplicate: ==
            ),
            using: codec,
            routeInbox: routeInbox,
            pendingSources: [intentStore, notificationInbox]
        )

        bootstrap = .init(
            configuration: runtimeConfiguration,
            lifecyclePlan: .init(
                activeTasks: [
                    routePipeline.task(name: "synchronizePendingRoutes")
                ],
                skipFirstActivePhase: true
            ),
            routePipeline: routePipeline
        )
    }
}
```

Recommended placement:

- root SwiftUI entry: `.mhAppRuntimeBootstrap(assembly.bootstrap)`
- app-owned navigation mutations: register the apply closure with
  `.mhRouteHandler(routeInbox) { route in ... }`
- direct route apply is still valid when no replace-latest handoff slot is
  needed

Preview guidance:

- keep the same assembly shape for live and preview factories
- make preview bootstrap with preview-safe services or an empty lifecycle plan
- omit external handoff sources only when the preview truly does not exercise
  route entry points
- keep model container ownership in the app's preview factory rather than
  moving it into MHPlatform

## Recipe 0A: Runtime-only App Setup

Apps that only need runtime/bootstrap mechanics can stop at
`MHAppRuntimeCore`.

```swift
import MHAppRuntimeCore

@MainActor
final class RuntimeOnlyAssembly {
    let bootstrap = MHAppRuntimeBootstrap(
        runtimeOnlyConfiguration: .init(
            preferencesSuiteName: "group.com.example.runtime-only"
        ),
        lifecyclePlan: .init()
    )
}

struct RuntimeOnlyRootView: View {
    let assembly: RuntimeOnlyAssembly

    var body: some View {
        ContentView()
            .mhAppRuntimeBootstrap(assembly.bootstrap)
    }
}
```

Preview/test guidance:

- use `.mhAppRuntimeEnvironment(_:)` when the view only needs runtime state
  injection
- keep preview-safe stores, model containers, and service doubles in the app
  factory
- do not adopt route/review/mutation shells unless the screen actually uses
  them

## Recipe 1: Runtime Root -> MHAppRuntimeBootstrap

Use this bootstrap when app startup needs runtime, lifecycle, and route root
integration to be assembled in one package-owned shell.

```swift
import MHAppRuntime
import MHDeepLinking
import MHLogging
import MHRouteExecution

@MainActor
final class AppRootModel {
    let bootstrap: MHAppRuntimeBootstrap

    init(logger: MHLogger) {
        let codec = MHDeepLinkCodec<AppRoute>(
            configuration: .init(
                customScheme: "myapp",
                preferredUniversalLinkHost: "example.com",
                allowedUniversalLinkHosts: ["example.com"],
                universalLinkPathPrefix: "MyApp",
                preferredTransport: .customScheme
            )
        )
        let routePipeline = MHAppRoutePipeline(
            routeLifecycle: .init(
                logger: logger,
                initialReadiness: false,
                isDuplicate: ==
            ),
            using: codec,
            pendingSources: [
                intentStore,
                notificationInbox
            ]
        ) { route in
            try await applyRoute(route)
        }
        bootstrap = .init(
            configuration: .init(
                subscriptionProductIDs: ["com.example.app.premium.monthly"],
                preferencesSuiteName: "group.com.example.app"
            ),
            lifecyclePlan: .init(
                startupTasks: [
                    .init(name: "loadConfiguration") {
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
    }

    func rootView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .mhAppRuntimeBootstrap(bootstrap)
    }
}
```

`bootstrap.routeInbox` is the package-owned handoff surface for app-owned
services such as notification, widget, or intent adapters. When route execution
should stop at a replace-latest handoff boundary before mutating navigation,
construct the pipeline with `routeInbox: MHObservableRouteInbox<Route>`.

Keep lifecycle placement explicit: route synchronization still belongs in the
`MHAppRuntimeLifecyclePlan` phase you choose for the app.

When multiple handoff sources need a reusable ordering outside route replay,
compose them first:

```swift
let handoffSources = MHDeepLinkSourceChain(
    intentStore,
    notificationInbox
)

let routePipeline = MHAppRoutePipeline(
    routeLifecycle: routeLifecycle,
    using: codec,
    pendingSources: [handoffSources],
) { route in
    try await applyRoute(route)
}
```

Use `MHRouteCoordinator` directly when the app needs a separate resolve/apply
pipeline or direct access to pending-queue introspection.

Ingress checklist:

- `onOpenURL`: parse and `ingest`
- `NSUserActivity`: convert to URL and `ingest`
- push notification tap: resolve target URL and `ingest`
- widget tap: receive URL and `ingest`
- App Intent handoff: convert intent params to URL/route and `ingest`

## Recipe 2: NotificationPlans + NotificationPayloads (Pure + Bridge Split)

Keep plan/payload composition pure.
Keep request creation/scheduling in app adapter layer.

```swift
import MHNotificationPayloads
import MHNotificationPlans

struct NotificationRefreshService {
    func refresh(now: Date, calendar: Calendar) -> ([MHReminderPlan], [[AnyHashable: Any]]) {
        let plans = MHReminderPlanner.build(
            candidates: reminderCandidates(),
            policy: reminderPolicy(),
            now: now,
            calendar: calendar
        )

        let codec = MHNotificationPayloadCodec()
        let userInfos = plans.map { plan in
            let payload = MHNotificationPayload(
                routes: .init(
                    defaultRouteURL: plan.primaryRouteURL,
                    fallbackRouteURL: plan.secondaryRouteURL,
                    actionRouteURLs: ["open-fallback": plan.secondaryRouteURL]
                ),
                metadata: ["kind": "reminder", "planId": plan.identifier]
            )
            return codec.encode(payload)
        }

        return (plans, userInfos)
    }
}
```

Optional bridge layer (app adapter responsibility):

```swift
#if canImport(UserNotifications)
import MHDeepLinking
import MHNotificationPayloads
import UserNotifications

func syncRequests(
    center: UNUserNotificationCenter,
    requests: [UNNotificationRequest],
    managedPrefix: String
) async -> MHNotificationRequestSyncOutcome {
    await MHNotificationOrchestrator.replaceManagedPendingRequests(
        center: center,
        requests: requests,
        matcher: .init(prefixes: [managedPrefix])
    )
}

func deliverNotificationTap(
    userInfo: [AnyHashable: Any],
    actionIdentifier: String,
    inbox: some MHDeepLinkURLDestination
) async -> MHNotificationRouteDeliveryOutcome {
    await MHNotificationOrchestrator.deliverRouteURL(
        userInfo: userInfo,
        actionIdentifier: actionIdentifier,
        destination: inbox
    )
}
#endif
```

## Recipe 3: MutationWorkflow -> ReviewPolicy

Trigger review policy only from meaningful success outcomes.

```swift
import MHMutationFlow
import MHReviewPolicy

struct SaveSummary: Sendable {
    let itemID: String
    let shouldSyncNotifications: Bool
    let shouldRequestReview: Bool
}

@MainActor
func runSaveAndMaybeRequestReview() async {
    let reviewPolicy = MHReviewPolicy(
        lotteryMaxExclusive: 10,
        requestDelay: .seconds(1)
    )
    let reviewFlow = MHReviewFlow(policy: reviewPolicy)
    let adapter = MHMutationAdapter<SaveSummary>.build { summary in
        if summary.shouldSyncNotifications {
            MHMutationStep.mainActor(name: "syncNotifications") {
                try await syncNotifications()
            }
        }

        if summary.shouldRequestReview {
            reviewFlow.step(name: "requestReview")
        }
    }

    do {
        let itemID = try await MHMutationWorkflow.runThrowing(
            name: "saveItem",
            operation: {
                try await saveItem()
            },
            adapter: adapter,
            projection: .closures(
                afterSuccess: { item in
                    SaveSummary(
                        itemID: item.id,
                        shouldSyncNotifications: true,
                        shouldRequestReview: true
                    )
                },
                returning: { item in
                    item.id
                }
            ),
            onEvent: { event in
                logMutationEvent(event)
            },
            configuration: .init(
                retryPolicy: .default
            )
        )
        logMutationSuccess(itemID)
    } catch let error as MHMutationWorkflowError {
        logMutationFailure(error)
    } catch is CancellationError {
        logMutationCancellation()
    } catch {
        logUnexpectedFailure(error)
    }
}
```

Recommended review-flow placement:

- use `reviewFlow.step(name:)` for successful mutation follow-up
- use `reviewFlow.task(name:)` for lifecycle or activation-style prompts
- keep app-specific effect/result to review-eligibility mapping outside
  MHPlatform
- use `MHMutationAdapter.build { ... }` when app-owned effect flags need
  conditional review, async, or main-actor follow-up steps

## Recipe 3A: Invalid Deep-link Handling

Treat invalid deep links as app-owned UX while keeping the intake mechanics in
MHPlatform.

```swift
@MainActor
func handleInvalidDeepLinks(
    routePipeline: MHAppRoutePipeline<AppRoute>,
    presentInvalidLinkAlert: (URL) -> Void
) {
    guard let invalidURL = routePipeline.lastParseFailureURL else {
        return
    }

    presentInvalidLinkAlert(invalidURL)
    routePipeline.clearLastParseFailure()
}
```

Recommended pattern:

- observe `routePipeline.lastParseFailureURL` near the root or navigation layer
- present app-owned error UI or logging based on that URL
- clear the retained URL after the app has handled it

## Recipe 4: Structured Logging + JSONL Analysis

Use this pattern when you need in-app inspection and machine-assisted analysis from a shared log stream.

```swift
import MHLogging
import SwiftUI

@MainActor
final class AppLogging {
    let policy: MHLogPolicy
    let store: MHLogStore
    let logger: MHLogger

    init() {
        policy = .default

        let jsonFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("app.logs.jsonl")
        let jsonSink = MHJSONLLogSink(
            fileURL: jsonFileURL,
            maximumFileSizeBytes: policy.maximumDiskBytes
        )

        store = MHLogStore(
            policy: policy,
            sinks: [MHOSLogSink(), jsonSink]
        )
        logger = MHLogger(
            #fileID,
            subsystem: "com.example.app",
            store: store,
            policy: policy
        )
    }

    func markLaunch() {
        logger.info("app launched")
    }
}

struct DebugLogView: View {
    let logging: AppLogging

    var body: some View {
        MHLogConsoleView(store: logging.store)
    }
}
```

## Adoption Notes

### Incomes 向け導入順

1. `MHDeepLinking` + `MHRouteExecution` を先行導入し、起動直後の deep link 取りこぼしを防ぐ。
2. `MHNotificationPlans` を導入し、既存通知候補から deterministic な `Plan` を生成する。
3. `MHNotificationPayloads` を導入し、payload codec と route resolver を統一する。
4. `MHMutationWorkflow` と `MHMutationAdapter` で更新系ワークフローの
   ordered follow-up steps と default failure mapping を標準化する。
5. `MHPersistenceMaintenance` と `MHPreferences` を段階導入し、起動時保守処理と typed preferences を統一する。
6. 最後に `MHReviewPolicy` を `MHMutationOutcome.succeeded` 起点で接続する。
7. `MHLogging` を導入し、Debug画面で `MHLogConsoleView` による検索と JSONL 抽出を提供する。

### Cookle 向け導入順

1. `MHPreferences` と `MHNotificationPayloads` を先に入れて設定/通知の契約を安定化する。
2. `MHDeepLinking` + `MHRouteExecution` を導入し、widget/push 入口を readiness-aware に統合する。
3. `MHNotificationPlans` を導入して候補選定を deterministic 化する。
4. `MHMutationWorkflow` を保存系処理へ適用し、app-owned effect metadata を
   ordered follow-up steps へ寄せる。
5. `MHPersistenceMaintenance` を導入して migration/reset orchestration を共通化する。
6. `MHReviewPolicy` は成功体験フローに限定して接続する。
7. `MHLogging` を導入し、`Logger(#file)` 相当の呼び出しを `MHLogger` に統一する。

### 役割分離（必須）

- domain rules は各アプリ/ドメインライブラリが保持する。
- UI state（画面遷移、sheet/focus、view model state）は各アプリが保持する。
- SwiftData query と `ModelContext` 利用方針は各アプリが保持する。
