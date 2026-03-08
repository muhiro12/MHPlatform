# MHPlatform Integration Cookbook

This cookbook focuses on composable end-to-end integration patterns.

## Recipe 1: DeepLink -> ObservableInbox -> RouteLifecycle

Use this pipeline when URLs can arrive before UI/bootstrap readiness.

```swift
import MHDeepLinking
import MHLogging
import MHRouteExecution

@MainActor
final class AppRoutePipeline {
    private let codec: MHDeepLinkCodec<AppRoute>
    let inbox: MHObservableDeepLinkInbox
    private let routeLifecycle: MHRouteLifecycle<AppRoute>

    init(logger: MHLogger) {
        codec = .init(configuration: .init(
            customScheme: "myapp",
            preferredUniversalLinkHost: "example.com",
            allowedUniversalLinkHosts: ["example.com"],
            universalLinkPathPrefix: "MyApp",
            preferredTransport: .customScheme
        ))
        inbox = .init()

        routeLifecycle = .init(
            logger: logger,
            initialReadiness: false,
            isDuplicate: ==
        )
    }

    func receiveRoute(_ route: AppRoute) async {
        await inbox.ingest(route, using: codec)
    }

    func receiveURL(_ url: URL) async {
        await inbox.ingest(url)
    }

    func setReady(_ ready: Bool) async {
        await routeLifecycle.setReadiness(ready)
        _ = try? await routeLifecycle.applyPendingIfReady { route in
            try await applyRoute(route)
        }
    }

    func drainPendingURL() async {
        _ = try? await routeLifecycle.submitLatest(
            from: inbox,
            using: codec,
            applyOnMainActor: { route in
                try await applyRoute(route)
            }
        )
    }
}
```

Swap in `MHDeepLinkInbox` when SwiftUI observation is unnecessary, or
`MHDeepLinkStore` when the pending URL needs persistence across launches.

When multiple handoff sources can produce a pending URL, compose them first and
keep the route pipeline single-sourced:

```swift
let routeInbox = MHObservableDeepLinkInbox()
let handoffSources = MHDeepLinkSourceChain(
    intentStore,
    notificationInbox
)

await handoffSources.forwardLatestURL(to: routeInbox)
```

Use `MHRouteCoordinator` directly when the app needs a separate resolve/apply
pipeline or direct access to pending-queue introspection.

Lifecycle placement checklist:

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
        isManagedIdentifier: { $0.hasPrefix(managedPrefix) }
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
    let adapter = MHMutationAdapter<SaveSummary>.build { summary in
        if summary.shouldSyncNotifications {
            MHMutationStep.mainActor(name: "syncNotifications") {
                try await syncNotifications()
            }
        }

        if summary.shouldRequestReview {
            MHMutationStep.mainActor(name: "requestReview") {
                _ = await MHReviewRequester.requestIfNeeded(
                    policy: reviewPolicy
                )
            }
        }
    }

    do {
        let itemID = try await MHMutationWorkflow.runThrowing(
            name: "saveItem",
            operation: {
                try await saveItem()
            },
            adapter: adapter,
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
