# MHPlatform Integration Cookbook

This cookbook focuses on composable end-to-end integration patterns.

## Recipe 1: DeepLink -> Inbox -> Resolution -> Executor

Use this pipeline when URLs can arrive before UI/bootstrap readiness.

```swift
import MHDeepLinking
import MHRouteExecution

actor AppRoutePipeline {
    private let codec: MHDeepLinkCodec<AppRoute>
    private let inbox = MHDeepLinkInbox()
    private let coordinator: MHRouteCoordinator<AppRoute, RouteApplyToken>

    init() {
        codec = .init(configuration: .init(
            customScheme: "myapp",
            preferredUniversalLinkHost: "example.com",
            allowedUniversalLinkHosts: ["example.com"],
            universalLinkPathPrefix: "MyApp",
            preferredTransport: .customScheme
        ))

        let executor = MHRouteExecutor<AppRoute, RouteApplyToken>(
            resolve: { route in
                try await resolveRoute(route)
            },
            apply: { token in
                try await applyRoute(token)
            }
        )

        coordinator = .init(
            initialReadiness: false,
            executor: executor,
            isDuplicate: { lhs, rhs in lhs == rhs }
        )
    }

    func receiveURL(_ url: URL) async {
        guard codec.parse(url) != nil else {
            return
        }
        await inbox.ingest(url)
    }

    func setReady(_ ready: Bool) async {
        await coordinator.setReadiness(ready)
        _ = try? await coordinator.applyPendingIfReady()
    }

    func drainInboxOnce() async {
        guard let url = await inbox.consumeLatest(),
              let route = codec.parse(url) else {
            return
        }

        _ = try? await coordinator.submit(route)
    }
}
```

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
#endif
```

## Recipe 3: MutationOutcome -> ReviewPolicy

Trigger review policy only from meaningful success outcomes.

```swift
import MHMutationFlow
import MHReviewPolicy

@MainActor
func runSaveAndMaybeRequestReview() async {
    let mutation = MHMutation<Void>(
        name: "saveItem",
        operation: {
            try await saveItem()
        }
    )

    let run = MHMutationRunner.start(
        mutation: mutation,
        retryPolicy: .init(maximumAttempts: 3, backoff: .fixed(.milliseconds(200))),
        afterSuccess: [
            .init(name: "syncNotifications") { try await syncNotifications() }
        ]
    )

    for await event in run.events {
        logMutationEvent(event)
    }

    let outcome = await run.outcome.value
    guard case .succeeded = outcome else {
        return
    }

    let reviewOutcome = await MHReviewRequester.requestIfNeeded(
        policy: .init(lotteryMaxExclusive: 10, requestDelay: .seconds(1))
    )
    logReviewOutcome(reviewOutcome)
}
```

## Adoption Notes

### Incomes 向け導入順

1. `MHDeepLinking` + `MHRouteExecution` を先行導入し、起動直後の deep link 取りこぼしを防ぐ。
2. `MHNotificationPlans` を導入し、既存通知候補から deterministic な `Plan` を生成する。
3. `MHNotificationPayloads` を導入し、payload codec と route resolver を統一する。
4. `MHMutationFlow` で更新系ワークフローの retry/cancel/event/outcome を標準化する。
5. `MHPersistenceMaintenance` と `MHPreferences` を段階導入し、起動時保守処理と typed preferences を統一する。
6. 最後に `MHReviewPolicy` を `MHMutationOutcome.succeeded` 起点で接続する。

### Cookle 向け導入順

1. `MHPreferences` と `MHNotificationPayloads` を先に入れて設定/通知の契約を安定化する。
2. `MHDeepLinking` + `MHRouteExecution` を導入し、widget/push 入口を readiness-aware に統合する。
3. `MHNotificationPlans` を導入して候補選定を deterministic 化する。
4. `MHMutationFlow` を保存系処理へ適用し、Outcome/Event ベースの副作用判断へ寄せる。
5. `MHPersistenceMaintenance` を導入して migration/reset orchestration を共通化する。
6. `MHReviewPolicy` は成功体験フローに限定して接続する。

### 役割分離（必須）

- domain rules は各アプリ/ドメインライブラリが保持する。
- UI state（画面遷移、sheet/focus、view model state）は各アプリが保持する。
- SwiftData query と `ModelContext` 利用方針は各アプリが保持する。
