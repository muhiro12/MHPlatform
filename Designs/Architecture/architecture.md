# MHPlatform Architecture

## Public Modules

- `MHAppRuntime`
- `MHDeepLinking`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHMutationFlow`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHReviewPolicy`

The package name is `MHPlatform`, but consumers import concrete module names instead of a single umbrella module.
MHPlatform is maintained as an internal app platform foundation for reusable non-domain app infrastructure.

## Platform Baseline

- iOS 18.0+
- macOS 15.0+

## Module Boundaries

### `MHAppRuntime`

Integration contract:
[`MHAppRuntime`](integration-contracts.md#mhappruntime)

- Owns runtime-start orchestration and idempotent startup entry point:
  `MHAppRuntime.startIfNeeded()`
- Owns app-facing platform configuration and shared status surfaces:
  `MHAppConfiguration`, `MHPremiumStatus`, `MHAdsAvailability`
- Owns app-facing SwiftUI runtime surfaces:
  paywall section, native ad view, license view
- Does not own domain policy, app-specific route state, or persistence model rules

### `MHDeepLinking`

Integration contract:
[`MHDeepLinking`](integration-contracts.md#mhdeeplinking)

- Owns URL grammar primitives:
  `MHDeepLinkConfiguration`, `MHDeepLinkDescriptor`, `MHDeepLinkCodec`
- Owns pending-route handoff primitives:
  `MHDeepLinkInbox`, `MHDeepLinkStore`
- Does not own app navigation state or route execution

### `MHNotificationPlans`

Integration contract:
[`MHNotificationPlans`](integration-contracts.md#mhnotificationplans)

- Owns deterministic schedule planning:
  `MHReminderPlanner`, `MHSuggestionPlanner`
- Owns schedule input/output models:
  candidates, policies, plans, delivery time
- Does not own `UNNotificationRequest`, categories, authorization, or payload composition

### `MHNotificationPayloads`

Integration contract:
[`MHNotificationPayloads`](integration-contracts.md#mhnotificationpayloads)

- Owns routing-focused notification payload primitives:
  `MHNotificationPayload`, `MHNotificationRouteTargets`, `MHNotificationPayloadCodec`
- Owns action/category descriptors and route resolution:
  `MHNotificationActionDescriptor`, `MHNotificationCategoryDescriptor`, `MHNotificationRouteResolver`
- Owns optional `UserNotifications` bridge and orchestration helpers behind `#if canImport(UserNotifications)`:
  `MHNotificationCentering`, `MHNotificationOrchestrator`, `MHNotificationRequestSyncOutcome`
- Does not own notification text templates, attachment generation, or app-specific scheduling policy

### `MHMutationFlow`

Integration contract:
[`MHMutationFlow`](integration-contracts.md#mhmutationflow)

- Owns mutation retry, cancellation, and post-success side-effect orchestration
- Exposes observable execution events through `MHMutationEvent`
- Does not own persistence, widgets, notifications, or review APIs directly

### `MHRouteExecution`

Integration contract:
[`MHRouteExecution`](integration-contracts.md#mhrouteexecution)

- Owns route execution orchestration primitives:
  `MHRouteExecutor`, `MHRouteCoordinator`, `MHRouteExecutionOutcome`
- Owns readiness-aware pending queue behavior with latest-wins semantics
- Does not own URL parsing, route type definitions, persistence access, or UI state models

### `MHPersistenceMaintenance`

Integration contract:
[`MHPersistenceMaintenance`](integration-contracts.md#mhpersistencemaintenance)

- Owns store-file migration and legacy cleanup primitives:
  `MHStoreMigrationPlan`, `MHStoreMigrator`, `MHStoreMigrationOutcome`,
  `MHStoreLegacyCleanupOutcome`, `MHStoreMigrationSkipReason`
- Owns ordered destructive-reset orchestration primitives:
  `MHDestructiveResetStep`, `MHDestructiveResetService`,
  `MHDestructiveResetOutcome`, `MHDestructiveResetEvent`
- Does not own app-specific persistence model types, migration validation, or data-deletion policy decisions

### `MHPreferences`

Integration contract:
[`MHPreferences`](integration-contracts.md#mhpreferences)

- Owns typed preference keys and `UserDefaults` read/write primitives
- Owns `AppStorage` bridge initializers for primitive preference keys
- Stores codable values as `Data` without legacy string-format fallback
- Does not define app-specific preference key names or policy

### `MHReviewPolicy`

Integration contract:
[`MHReviewPolicy`](integration-contracts.md#mhreviewpolicy)

- Owns review-request policy primitives:
  `MHReviewPolicy`, `MHReviewRequestOutcome`
- Owns high-level requester flow:
  `MHReviewRequester`
- Uses platform-aware fallback behavior for non-iOS builds
- Does not own app-specific lifecycle triggers or presentation timing policy beyond configured delay/lottery

## Dependency Rules

- Module dependencies are intentionally flat for v1.
- `MHAppRuntime` depends on `MHPreferences`, `StoreKitWrapper`,
  `GoogleMobileAdsWrapper` (iOS), and `LicenseList` (iOS).
- `MHDeepLinking` has no dependency on the other modules.
- `MHNotificationPlans` has no dependency on the other modules.
- `MHNotificationPayloads` has no dependency on the other modules.
- `MHMutationFlow` has no dependency on the other modules.
- `MHRouteExecution` has no dependency on the other modules.
- `MHPersistenceMaintenance` has no dependency on the other modules.
- `MHPreferences` has no dependency on the other modules.
- `MHReviewPolicy` has no dependency on the other modules.
- ExampleApp may import all public modules, but package targets must stay independent.

## Why No Generic Core Layer

- The duplicated logic found in Incomes and Cookle is concrete and concern-specific.
- Introducing `MHCore`, `MHObservability`, or a generic workflow layer now would create abstraction before stable shared usage exists.
- If repeated low-level types emerge later, they can be extracted after at least two modules genuinely need them.

## Out Of Scope

- app-specific `UNUserNotificationCenter` adoption wiring in Incomes/Cookle
- SwiftUI navigation-state executors
- shared migration policy for existing app preference formats
- remote config
- a generic umbrella `MHPlatform` product

## Verification Expectations

- Changes stay inside `MHPlatform/`.
- `Incomes/` and `Cookle/` remain read-only reference material.
- `swift test` must pass.
- `MHPlatformExample` in `Example/` must build through `xcodebuild`.
