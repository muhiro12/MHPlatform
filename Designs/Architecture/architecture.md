# MHPlatform Architecture

## Public Products

- `MHPlatform`
- `MHPlatformCore`
- `MHAppRuntime`
- `MHAppRuntimeCore`
- `MHAppRuntimeDefaults`
- `MHAppRuntimeAds`
- `MHAppRuntimeLicenses`
- `MHDeepLinking`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHMutationFlow`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHReviewPolicy`
- `MHLogging`
- `MHPlatformTesting`

`MHPlatform` is the full app umbrella. It re-exports `MHPlatformCore`,
`MHAppRuntime`, `MHMutationFlow`, and `MHReviewPolicy`.
`MHPlatformCore` is the shared-package umbrella. It re-exports the shared-safe
modules used by watch-capable and library-first package adopters.

## Public Modules

- `MHDeepLinking`
- `MHLogging`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHPlatformTesting`

Consumers may either `import MHPlatform` for app targets, `import MHPlatformCore`
for shared packages, or import concrete module names directly for granular
adoption. Third-party runtime symbols remain direct dependencies even when the
full umbrella is adopted.
MHPlatform is maintained as an internal app platform foundation for reusable
non-domain app infrastructure.

## Platform Baseline

- iOS 18.0+
- macOS 15.0+
- watchOS 11.0+

## Adoption Snapshot

- Incomes and Cookle currently adopt the umbrella `MHPlatform` product.
- `MHAppRuntime` is the primary shared runtime/startup surface already used in
  both apps.
- `MHReviewPolicy` is shared today, but review triggers and surrounding
  workflow decisions remain app-specific.
- `MHRouteExecution` now includes both low-level queue/executor primitives and
  the higher-level `MHRouteLifecycle` helper. Both apps already use the
  lifecycle shell while route enums, parsing, and apply closures remain
  app-owned.
- `MHMutationFlow` now includes both the low-level runner and the higher-level
  `MHMutationWorkflow` shell shaped by the local mutation workflow wrappers
  already present in both apps, while app-side cutover remains deferred.
- Recent platform-first work adds helper surfaces for route execution,
  deep-link handoff, logging setup, mutation adapter composition, and
  mutation workflow shells without moving app-owned route/effect models into
  MHPlatform.

## Module Boundaries

### `MHPlatformCore`

- Re-exports the shared-package-safe infrastructure modules:
  `MHDeepLinking`, `MHLogging`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHRouteExecution`,
  `MHPersistenceMaintenance`, and `MHPreferences`
- Exists so shared packages can adopt one umbrella without picking up
  `MHAppRuntime` or third-party runtime adapters
- Does not own `MHAppRuntime`, mutation workflow, or review workflow surfaces

### `MHAppRuntimeCore`

- Owns runtime-start orchestration and idempotent startup entry points:
  `MHAppRuntime.start()`, `MHAppRuntime.startIfNeeded()`
- Owns app-facing platform configuration and shared status surfaces:
  `MHAppConfiguration`, `MHPremiumStatus`, `MHAdsAvailability`
- Owns SwiftUI runtime/bootstrap/lifecycle and route-pipeline primitives:
  `MHAppRuntimeBootstrap`, `MHAppRuntimeLifecycle`, `MHAppRoutePipeline`
- Does not own StoreKit, ads, or license adapters

### `MHAppRuntime`

Integration contract:
[`MHAppRuntime`](integration-contracts.md#mhappruntime)

- Re-exports `MHAppRuntimeCore` for convenience adoption
- Owns the full default adapter assembly path by composing the split defaults
  bundles below
- Owns app-facing default runtime surfaces backed by those adapters:
  paywall section, native ad view, license view
- Serves as the main shared startup/runtime surface already adopted by Incomes
  and Cookle
- Does not own domain policy, app-specific route state, or persistence model rules

### `MHAppRuntimeDefaults`

- Owns the package-owned preference store and StoreKit convenience bundle:
  `MHAppRuntimeDefaultsBundle`
- Exposes `preferenceStore`, `startStore`, and
  `subscriptionSectionViewBuilder` for explicit composition into
  `MHAppRuntimeCore.MHAppRuntime`
- Uses `StoreKitWrapper` only where that dependency is available

### `MHAppRuntimeAds`

- Owns the package-owned ads convenience bundle:
  `MHAppRuntimeAdsBundle`
- Exposes `startAds` and `nativeAdViewBuilder` for explicit composition into
  `MHAppRuntimeCore.MHAppRuntime`
- Uses `GoogleMobileAdsWrapper` only where that dependency is available

### `MHAppRuntimeLicenses`

- Owns the package-owned licenses convenience bundle:
  `MHAppRuntimeLicensesBundle`
- Exposes `licensesViewBuilder` for explicit composition into
  `MHAppRuntimeCore.MHAppRuntime`
- Uses `LicenseList` only where that dependency is available

### `MHDeepLinking`

Integration contract:
[`MHDeepLinking`](integration-contracts.md#mhdeeplinking)

- Owns URL grammar primitives:
  `MHDeepLinkConfiguration`, `MHDeepLinkDescriptor`, `MHDeepLinkCodec`
- Owns pending-route handoff primitives:
  `MHDeepLinkInbox`, `MHObservableDeepLinkInbox`, `MHDeepLinkStore`,
  `MHDeepLinkURLDestination`
- Owns codec-backed route handoff helpers on inbox, observable inbox, and
  store while keeping URL storage as the persisted representation
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
  `MHNotificationCentering`, `MHNotificationOrchestrator`,
  `MHNotificationRequestSyncOutcome`
- Owns notification-to-deep-link destination delivery helpers without taking
  ownership of app-specific fallback policy or route semantics
- Does not own notification text templates, attachment generation, or app-specific scheduling policy

### `MHMutationFlow`

Integration contract:
[`MHMutationFlow`](integration-contracts.md#mhmutationflow)

- Owns app-facing workflow shells:
  `MHMutationWorkflow`, `MHMutationWorkflowError`
- Owns mutation retry, cancellation, and post-success side-effect orchestration
- Owns the app-facing adapter bridge from successful mutation values to ordered
  `MHMutationStep`s through `MHMutationAdapter`
- Owns additive adapter composition helpers for sequencing fixed and
  value-derived post-success steps
- Exposes low-level runner and observable execution events through
  `MHMutationRunner`, `MHMutationEvent`
- Does not define a shared cross-app mutation metadata, hint, or effect schema
- Does not own persistence, widgets, notifications, or review APIs directly

### `MHRouteExecution`

Integration contract:
[`MHRouteExecution`](integration-contracts.md#mhrouteexecution)

- Owns app-facing lifecycle helper:
  `MHRouteLifecycle`
- Owns route execution orchestration primitives:
  `MHRouteExecutor`, `MHRouteCoordinator`, `MHRouteExecutionOutcome`
- Owns readiness-aware pending queue behavior with latest-wins semantics
- Owns a logger-backed helper path for parsed URLs, pending-source drain, and
  replaying queued routes
- Owns an identity-route convenience path for `Route == Outcome` flows while
  leaving route application in app-owned closures
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
- Owns package-owned requester and orchestration surfaces:
  `MHReviewRequester`, `MHReviewFlow`
- Owns runtime-task and mutation-step integration helpers for review triggers
- Uses platform-aware fallback behavior for non-iOS builds
- Does not own app-specific lifecycle triggers or presentation timing policy beyond configured delay/lottery

### `MHLogging`

Integration contract:
[`MHLogging`](integration-contracts.md#mhlogging)

- Owns structured log models and logger surface:
  `MHLogLevel`, `MHLogEvent`, `MHLogger`
- Owns in-memory queryable store:
  `MHLogStore`, `MHLogQuery`
- Owns sink abstractions and default adapters:
  `MHLogSink`, `MHOSLogSink`, `MHJSONLLogSink`
- Owns a lightweight logger setup helper:
  `MHLoggerFactory`
- Owns reusable log console UI:
  `MHLogConsoleView`, with watchOS-safe availability guards for unsupported
  selection and clipboard features
- Does not own app-specific PII masking policy, alerting policy, or external telemetry backend contracts

### `MHPlatformTesting`

- Owns package-level test doubles and recorders intended for app and package
  tests:
  `MHNotificationCenterDouble`, `MHDeepLinkURLRecorder`,
  `MHLogSinkRecorder`, `MHRouteExecutionRecorder`
- Depends on runtime modules only as needed to conform to their public
  test-facing protocols
- Is intentionally separate from the umbrella `MHPlatform` product so
  production targets do not pick up testing helpers by default

## Dependency Rules

- Module dependencies are intentionally flat for v1.
- `MHPlatform` depends on `MHPlatformCore`, `MHAppRuntime`, `MHMutationFlow`,
  and `MHReviewPolicy`, and must stay a thin aggregation layer without
  independent runtime logic.
- `MHPlatformCore` depends on `MHDeepLinking`, `MHLogging`,
  `MHNotificationPlans`, `MHNotificationPayloads`, `MHRouteExecution`,
  `MHPersistenceMaintenance`, and `MHPreferences`.
- `MHAppRuntimeCore` depends on `MHDeepLinking`, `MHLogging`,
  `MHPreferences`, and `MHRouteExecution`.
- `MHAppRuntime` depends on `MHAppRuntimeCore`, `MHAppRuntimeDefaults`,
  `MHAppRuntimeAds`, and `MHAppRuntimeLicenses`.
- `MHAppRuntimeDefaults` depends on `MHAppRuntimeCore`, `MHPreferences`, and
  `StoreKitWrapper` (iOS, macOS).
- `MHAppRuntimeAds` depends on `MHAppRuntimeCore` and
  `GoogleMobileAdsWrapper` (iOS).
- `MHAppRuntimeLicenses` depends on `MHAppRuntimeCore` and `LicenseList` (iOS).
- `MHDeepLinking` has no dependency on the other modules.
- `MHNotificationPlans` has no dependency on the other modules.
- `MHNotificationPayloads` depends on `MHDeepLinking` for shared pending-route
  destination delivery.
- `MHMutationFlow` has no dependency on the other modules.
- `MHRouteExecution` depends on `MHDeepLinking` for pending-source handoff
  helpers and on `MHLogging` for `MHRouteLifecycle` outcome logging.
- `MHPersistenceMaintenance` has no dependency on the other modules.
- `MHPreferences` has no dependency on the other modules.
- `MHReviewPolicy` depends on `MHAppRuntimeCore`, `MHLogging`, and
  `MHMutationFlow` for runtime-task, outcome logging, and mutation-step
  integration.
- `MHLogging` has no dependency on the other modules.
- `MHPlatformTesting` depends on `MHDeepLinking`, `MHLogging`, and
  `MHNotificationPayloads` to provide reusable doubles and recorders.
- ExampleApp may import the full `MHPlatform` umbrella, but shared package
  targets should prefer `MHPlatformCore` or granular modules.
- Adopting `MHPlatform` does not make third-party wrapper symbols public; those
  remain direct consumer dependencies and imports.

## Why No Generic Core Layer

- The duplicated logic found in Incomes and Cookle is concrete and concern-specific.
- Introducing `MHCore` or a generic workflow layer would create abstraction before stable shared usage exists.
- If repeated low-level types emerge later, they can be extracted after at least two modules genuinely need them.

## Out Of Scope

- app-specific `UNUserNotificationCenter` adoption wiring in Incomes/Cookle
- SwiftUI navigation-state executors
- shared migration policy for existing app preference formats
- shared mutation outcome/effect schema across Incomes and Cookle
- remote config
- collapsing all shared infrastructure into a monolithic implementation target

## Verification Expectations

- Changes stay inside `MHPlatform/`.
- `Incomes/` and `Cookle/` remain read-only reference material.
- `swift test` must pass.
- `MHPlatformExample` in `Example/` must build through `xcodebuild`.
