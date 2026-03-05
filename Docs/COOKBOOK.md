# MHKit Example Integration Cookbook

## Adoption Principles

- Keep adapters thin:
  app targets translate platform APIs into MHKit input models and consume
  outputs.
- Prefer lifecycle-first placement:
  wire each module where the app already owns that concern.
- Keep domain ownership local:
  pass domain values into MHKit, but do not move domain rules into MHKit.
- Compose modules explicitly:
  avoid hidden framework layers or cross-module dependencies.

## MHDeepLinking

Where to call this:
`onOpenURL`, app-delegate URL handlers, or cold-start URL replay.

```swift
import MHDeepLinking

let codec = MHDeepLinkCodec<AppRoute>(configuration: deepLinkConfiguration)
let inbox = MHDeepLinkInbox()

func receiveIncomingURL(_ url: URL) async {
    guard codec.parse(url) != nil else {
        return
    }
    await inbox.store(url)
}
```

## MHNotificationPlans

Where to call this:
notification refresh workflows after settings or candidate updates.

```swift
import MHNotificationPlans

let reminderPlans = MHReminderPlanner.build(
    candidates: reminderCandidates,
    policy: reminderPolicy,
    now: now,
    calendar: calendar
)
let suggestionPlans = MHSuggestionPlanner.build(
    candidates: suggestionCandidates,
    policy: suggestionPolicy,
    now: now,
    calendar: calendar
)
```

## MHNotificationPayloads

Where to call this:
notification registration/response handlers in app adapter layers.

```swift
import MHNotificationPayloads

let codec = MHNotificationPayloadCodec()
let userInfo = codec.encode(notificationPayload)

let routeURL = MHNotificationRouteResolver.resolveRouteURL(
    payload: notificationPayload,
    response: .init(actionIdentifier: actionIdentifier)
)
```

## MHMutationFlow

Where to call this:
app workflow services that combine mutation and side effects.

```swift
import MHMutationFlow

let outcome = await MHMutationRunner.run(
    operation: { try await saveDraft() },
    retryPolicy: .default,
    afterSuccess: [
        .init(name: "syncNotifications") { try await syncNotifications() },
        .init(name: "reloadWidgets") { reloadWidgets() }
    ]
)
```

## MHRouteExecution

Where to call this:
route orchestration service that can queue until app readiness.

```swift
import MHRouteExecution

let executor = MHRouteExecutor<AppRoute, AppRouteOutcome>(
    resolve: resolveRoute,
    apply: applyRouteOutcome
)
let coordinator = MHRouteCoordinator(isReady: isReadyToApply, executor: executor)

let resolution = try await coordinator.handle(route)
```

## MHPersistenceMaintenance

Where to call this:
startup migration gates and user-triggered destructive reset workflows.

```swift
import MHPersistenceMaintenance

let migrationResult = try MHStoreMigrator.migrateIfNeeded(plan: migrationPlan)

let resetOutcome = await MHDestructiveResetService.run(
    steps: resetSteps
) { event in
    logger.info("\(event)")
}
```

## MHPreferences

Where to call this:
settings, feature flags, and bootstrap preference reads.

```swift
import MHPreferences

let store = MHPreferenceStore(userDefaults: sharedDefaults)
let enabledKey = MHBoolPreferenceKey("notification.enabled", default: true)

let isEnabled = store.bool(for: enabledKey)
store.set(false, for: enabledKey)
```

## MHReviewPolicy

Where to call this:
post-success workflows on `MainActor` after meaningful user completion.

```swift
import MHReviewPolicy

@MainActor
func maybeRequestReview() async -> MHReviewRequestOutcome {
    let policy = MHReviewPolicy(lotteryMaxExclusive: 10, requestDelay: .seconds(2))
    return await MHReviewRequester.requestIfNeeded(policy: policy)
}
```

## Combined: DeepLinking + RouteExecution

Where to call this:
`onOpenURL` in the app target with readiness-aware route application.

```swift
import MHDeepLinking
import MHRouteExecution

func onOpenURL(_ url: URL) {
    guard let route = deepLinkCodec.parse(url) else { return }
    Task {
        _ = try await routeCoordinator.handle(route)
        _ = try await routeCoordinator.applyPendingIfNeeded()
    }
}
```

## Combined: NotificationPlans + NotificationPayloads

Where to call this:
notification synchronization service after candidate recomputation.

```swift
import MHNotificationPayloads
import MHNotificationPlans
import UserNotifications

let plans = MHReminderPlanner.build(
    candidates: candidates,
    policy: policy,
    now: now,
    calendar: calendar
)
let requests = plans.map(makeRequestFromPlan)
let syncResult = await MHNotificationOrchestrator.replaceManagedPendingRequests(
    center: UNUserNotificationCenter.current(),
    requests: requests,
    isManagedIdentifier: { $0.hasPrefix(policy.identifierPrefix) }
)
```
