# MHPlatform Architecture

## Public Products

- `MHPlatform`
- `MHPlatformCore`
- `MHAppRuntime`
- `MHAppRuntimeDefaults`
- `MHAppRuntimeAds`
- `MHAppRuntimeLicenses`
- `MHDeepLinking`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHUserNotifications`
- `MHNotificationDeepLinking`
- `MHMutationFlow`
- `MHMutationLogging`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHPreferencesUI`
- `MHReviewPolicy`
- `MHReviewRequesting`
- `MHReviewFlow`
- `MHLogging`
- `MHLoggingUI`
- `MHPlatformTesting`

`MHPlatform` is the full app umbrella. It re-exports `MHPlatformCore`,
`MHAppRuntime`, optional UI bridge products, mutation shells, logging bridge,
and review shells, and it keeps the one-step default runtime convenience APIs.
`MHPlatformCore` is the shared-package umbrella. It re-exports the shared-safe
modules used by watch-capable and library-first package adopters, without
SwiftUI/UI bridge targets or workflow shells.
`MHAppRuntime` is the advanced app-runtime foundation for narrower app roots
and explicit split-runtime-bundle composition.

## Public Modules

- `MHDeepLinking`
- `MHLogging`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHUserNotifications`
- `MHNotificationDeepLinking`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHPreferencesUI`
- `MHMutationFlow`
- `MHMutationLogging`
- `MHReviewPolicy`
- `MHReviewRequesting`
- `MHReviewFlow`
- `MHLoggingUI`
- `MHPlatformTesting`

Consumers may either `import MHPlatform` for default app targets,
`import MHAppRuntime` for advanced app-runtime composition,
`import MHPlatformCore` for shared packages, or import concrete module names
directly for granular adoption. Third-party runtime symbols remain direct
dependencies even when the full umbrella is adopted.
MHPlatform is maintained as an internal app platform foundation for reusable
non-domain app infrastructure.

## Platform Baseline

- iOS 18.0+
- macOS 15.0+
- watchOS 11.0+

## Adoption Snapshot

- Incomes and Cookle currently adopt the umbrella `MHPlatform` product.
- `MHAppRuntime` remains the shared runtime/startup foundation already used
  transitively through `MHPlatform` in both apps and available directly for
  narrower app-root composition.
- `MHReviewPolicy`, `MHReviewRequesting`, and `MHReviewFlow` are split so
  pure review policy, direct platform requesting, and workflow wiring can be
  adopted independently while review timing remains app-specific.
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
- Does not own `MHAppRuntime`, SwiftUI/UI bridge targets, mutation workflow,
  or review workflow surfaces

### `MHPlatform`

- Re-exports `MHAppRuntime`, `MHPlatformCore`, `MHPreferencesUI`,
  `MHLoggingUI`, `MHMutationFlow`, `MHMutationLogging`,
  `MHNotificationDeepLinking`, `MHReviewPolicy`, `MHReviewRequesting`,
  `MHReviewFlow`, and `MHUserNotifications`
- Owns the one-step default app path through
  `MHAppRuntime(configuration:)` and
  `MHAppRuntimeBootstrap(configuration:...)`
- Directly composes the split runtime bundles behind that convenience surface
- Does not own additional runtime logic beyond aggregation and convenience
  assembly

### `MHAppRuntime`

- Owns runtime-start orchestration and idempotent startup entry points:
  `MHAppRuntime.start()`, `MHAppRuntime.startIfNeeded()`
- Owns app-facing platform configuration and shared status surfaces:
  `MHAppConfiguration`, `MHPremiumStatus`, `MHAdsAvailability`
- Owns SwiftUI runtime/bootstrap/lifecycle and route-pipeline primitives:
  `MHAppRuntimeBootstrap`, `MHAppRuntimeLifecycle`, `MHAppRoutePipeline`
- Does not own StoreKit, ads, or license adapters

### `MHAppRuntimeDefaults`

- Owns the package-owned preference store and StoreKit convenience bundle:
  `MHAppRuntimeDefaultsBundle`
- Exposes `preferenceStore`, `startStore`, and
  `subscriptionSectionFactory` for explicit composition into
  `MHAppRuntime`
- Uses `StoreKitWrapper` only where that dependency is available

### `MHAppRuntimeAds`

- Owns the package-owned ads convenience bundle:
  `MHAppRuntimeAdsBundle`
- Exposes `startAds` and `nativeAdFactory` for explicit composition into
  `MHAppRuntime`
- Uses `GoogleMobileAdsWrapper` only where that dependency is available

### `MHAppRuntimeLicenses`

- Owns the package-owned licenses convenience bundle:
  `MHAppRuntimeLicensesBundle`
- Exposes `licensesFactory` for explicit composition into
  `MHAppRuntime`
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
- Does not own `UserNotifications` adapters, notification-center orchestration,
  or deep-link destination delivery
- Does not own notification text templates, attachment generation, or app-specific scheduling policy

### `MHUserNotifications`

Integration contract:
[`MHUserNotifications`](integration-contracts.md#mhusernotifications)

- Owns optional `UserNotifications` bridge and orchestration helpers behind
  `#if canImport(UserNotifications)`:
  `MHNotificationCentering`, `MHNotificationOrchestrator`,
  `MHNotificationRouteDeliveryOutcome`,
  `MHNotificationRequestSyncOutcome`
- Depends on `MHNotificationPayloads` for payload decoding and route
  resolution
- Does not own app-specific fallback policy, route semantics, notification
  copy, or scheduling policy

### `MHNotificationDeepLinking`

Integration contract:
[`MHNotificationDeepLinking`](integration-contracts.md#mhnotificationdeeplinking)

- Owns notification-to-deep-link destination delivery helpers:
  `MHNotificationOrchestrator.deliverRouteURL(... destination:)`
- Depends on `MHUserNotifications` and `MHDeepLinking`
- Does not own route meaning, destination choice, or app-specific fallback
  policy

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

- Owns store-file relocation and legacy cleanup primitives:
  `MHStoreRelocationPlan`, `MHStoreRelocationSkipReason`,
  `MHStoreRelocationOutcome`, `MHLegacyStoreCleanupOutcome`,
  `MHStoreRelocationService`
- Owns ordered destructive-reset orchestration primitives:
  `MHDestructiveResetStep`, `MHDestructiveResetService`,
  `MHDestructiveResetOutcome`, `MHDestructiveResetEvent`
- Does not own app-specific persistence model types, schema migration plans,
  startup timing policy, validation policy, or data-deletion policy decisions

### `MHPreferences`

Integration contract:
[`MHPreferences`](integration-contracts.md#mhpreferences)

- Owns typed preference descriptors and `UserDefaults`-backed store primitives
- Stores codable values as `Data` without legacy string-format fallback
- Does not define app-specific preference key names or policy

### `MHPreferencesUI`

Integration contract:
[`MHPreferencesUI`](integration-contracts.md#mhpreferencesui)

- Owns SwiftUI wrappers built on `AppStorage`:
  `AppStorage` descriptor initializers, `MHCodablePreference`, and
  `MHOptionalCodablePreference`
- Depends on `MHPreferences` and does not introduce preference meaning,
  defaults, or schema policy

### `MHReviewPolicy`

Integration contract:
[`MHReviewPolicy`](integration-contracts.md#mhreviewpolicy)

- Owns review-request policy primitives:
  `MHReviewPolicy`
- Does not own platform requesting, logging, runtime tasks, mutation steps, or
  app-specific lifecycle triggers

### `MHReviewRequesting`

Integration contract:
[`MHReviewRequesting`](integration-contracts.md#mhreviewrequesting)

- Owns direct platform review requesting:
  `MHReviewRequester`, `MHReviewRequestOutcome`
- Uses platform-aware fallback behavior for non-iOS builds
- Does not own runtime-task or mutation-step integration

### `MHReviewFlow`

Integration contract:
[`MHReviewFlow`](integration-contracts.md#mhreviewflow)

- Owns package-owned runtime-task and mutation-step integration helpers for
  review triggers:
  `MHReviewFlow.task(name:)`, `MHReviewFlow.step(name:)`
- Owns optional review outcome logging through `MHLogging`
- Does not own app-specific lifecycle triggers or presentation timing policy
  beyond configured delay/lottery

### `MHLogging`

Integration contract:
[`MHLogging`](integration-contracts.md#mhlogging)

- Owns structured log models and logger surface:
  `MHLogLevel`, `MHLogEvent`, `MHLogger`
- Owns in-memory queryable store:
  `MHLogStore`, `MHLogQuery`
- Owns sink abstractions and default adapters:
  `MHLogSink`, `MHOSLogSink`
- Owns a lightweight logger setup helper:
  `MHLoggerFactory`, `MHLoggingBootstrap`
- Does not own app-specific PII masking policy, alerting policy, or external telemetry backend contracts

### `MHLoggingUI`

Integration contract:
[`MHLoggingUI`](integration-contracts.md#mhloggingui)

- Owns reusable log console UI:
  `MHLogConsoleView`, with watchOS-safe availability guards for unsupported
  selection and clipboard features
- Depends on `MHLogging` and does not own logging policy, sinks, PII masking,
  alerting, or telemetry backend contracts

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
- `MHPlatform` depends on `MHPlatformCore`, `MHAppRuntime`,
  `MHAppRuntimeDefaults`, `MHAppRuntimeAds`, `MHAppRuntimeLicenses`,
  `MHLoggingUI`, `MHMutationFlow`, `MHMutationLogging`,
  `MHNotificationDeepLinking`, `MHPreferencesUI`, `MHReviewPolicy`,
  `MHReviewRequesting`, `MHReviewFlow`, and `MHUserNotifications`, and must
  stay a thin aggregation layer without independent runtime logic.
- `MHPlatformCore` depends on `MHDeepLinking`, `MHLogging`,
  `MHNotificationPlans`, `MHNotificationPayloads`, `MHRouteExecution`,
  `MHPersistenceMaintenance`, and `MHPreferences`.
- `MHAppRuntime` depends on `MHDeepLinking`, `MHLogging`, `MHPreferences`, and
  `MHRouteExecution`.
- `MHAppRuntimeDefaults` depends on `MHAppRuntime`, `MHPreferences`, and
  `StoreKitWrapper` (iOS, macOS).
- `MHAppRuntimeAds` depends on `MHAppRuntime` and
  `GoogleMobileAdsWrapper` (iOS).
- `MHAppRuntimeLicenses` depends on `MHAppRuntime` and `LicenseList` (iOS).
- `MHDeepLinking` has no dependency on the other modules.
- `MHNotificationPlans` has no dependency on the other modules.
- `MHNotificationPayloads` has no dependency on the other modules.
- `MHUserNotifications` depends on `MHNotificationPayloads` for
  UserNotifications adapter helpers.
- `MHNotificationDeepLinking` depends on `MHDeepLinking` and
  `MHUserNotifications` for pending-route destination delivery.
- `MHMutationFlow` has no dependency on the other modules.
- `MHRouteExecution` depends on `MHDeepLinking` for pending-source handoff
  helpers and on `MHLogging` for `MHRouteLifecycle` outcome logging.
- `MHPersistenceMaintenance` has no dependency on the other modules.
- `MHPreferences` has no dependency on the other modules.
- `MHPreferencesUI` depends on `MHPreferences` for SwiftUI descriptor
  bindings.
- `MHReviewPolicy` has no dependency on the other modules.
- `MHReviewRequesting` depends on `MHReviewPolicy` for direct request attempts.
- `MHReviewFlow` depends on `MHAppRuntime`, `MHLogging`, `MHMutationFlow`,
  `MHReviewPolicy`, and `MHReviewRequesting` for runtime-task and
  mutation-step integration.
- `MHLogging` depends on `MHPreferences` for session snapshot descriptors.
- `MHLoggingUI` depends on `MHLogging` for the reusable log console.
- `MHPlatformTesting` depends on `MHDeepLinking`, `MHLogging`,
  `MHNotificationPayloads`, and `MHUserNotifications` to provide reusable
  doubles and recorders.
- ExampleApp may import the full `MHPlatform` umbrella, but shared package
  targets should prefer `MHPlatformCore` or granular modules.
- Adopting `MHPlatform` does not make third-party wrapper symbols public; those
  remain direct consumer dependencies and imports.

## Why No Generic Core Layer

- The duplicated logic found in Incomes and Cookle is concrete and concern-specific.
- Introducing `MHCore` or a generic workflow layer would create abstraction before stable shared usage exists.
- General-purpose replacement helpers for app-local utility extensions are not
  a platform architecture layer.
- If repeated low-level types emerge later, they can be extracted after at least two modules genuinely need them.

## Out Of Scope

- app-specific `UNUserNotificationCenter` adoption wiring in Incomes/Cookle
- SwiftUI navigation-state executors
- upgrade-specific preference compatibility policy across Incomes and Cookle
- shared mutation outcome/effect schema across Incomes and Cookle
- remote config
- collapsing all shared infrastructure into a monolithic implementation target

## Verification Expectations

- Changes stay inside `MHPlatform/`.
- `Incomes/` and `Cookle/` remain read-only reference material.
- Prefer XcodeBuildMCP for Apple build, test, run, Simulator, runtime log,
  screenshot, and UI snapshot evidence.
- Use XcodeBuildMCP `build_sim` / `test_sim` with
  `.swiftpm/xcode/package.xcworkspace` and the `MHPlatform-Package` scheme for
  package compile and test evidence.
- Use XcodeBuildMCP `build_sim` / `build_run_sim` with
  `Example/MHPlatformExample.xcodeproj` and the `MHPlatformExample` scheme for
  example app compile or runtime evidence.
- Run `bash ci_scripts/tasks/check_repository_rules.sh` for retained SwiftLint,
  models-directory consistency, and consumer fixture checks.
- Treat direct shell build/test scripts and `verify_*` scripts as compatibility
  or fallback wrappers when MCP is unavailable or not sufficient for a check.
- Inspect `.build/ci/runs/<RUN_ID>/` artifacts when verification fails.
