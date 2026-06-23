# MHPlatform Integration Contracts

## Contract Shape

Each module contract is defined with four fields:

- `Required Inputs`
- `Outputs`
- `Threading / Actor`
- `Intended Call Sites`

This document is normative for integration design.

## MHAppRuntime

### Required Inputs

- For advanced runtime-only adoption:
  - `MHAppConfiguration` for `MHAppRuntime(runtimeOnly:)`
  - or `MHAppRuntimeBootstrap(runtimeOnlyConfiguration:)`
- For advanced explicit runtime composition:
  - `MHAppConfiguration`
    - `subscriptionProductIDs`
    - `subscriptionGroupID`
    - `nativeAdUnitID`
    - `showsLicenses`
  - `MHPreferenceStore`
  - `startStore`
  - `MHRuntimeViewFactory` for `subscriptionSectionFactory`
  - optional `startAds`
  - optional `MHRuntimeNativeAdViewFactory`
  - optional `MHRuntimeViewFactory` for `licensesFactory`
- For the one-step default app path imported through `MHPlatform`:
  - `MHAppConfiguration`
  - package-owned composition of:
    - `MHAppRuntimeDefaultsBundle`
    - `MHAppRuntimeAdsBundle`
    - `MHAppRuntimeLicensesBundle`
- Optional route bootstrap primitive:
  - `MHAppRoutePipeline<Route>`
  - app-owned lifecycle placement for `routePipeline.task(name:)`

### Outputs

- Advanced runtime foundation:
  - `MHAppRuntime`
    - `init(runtimeOnly:)`
    - `init(configuration:preferenceStore:startStore:subscriptionSectionFactory:startAds:nativeAdFactory:licensesFactory:)`
- Bootstrap shell:
  - `MHAppRuntimeBootstrap`
    - `runtime`
    - `lifecyclePlan`
    - `routeInbox`
    - `makeLifecycle()`
    - `init(runtime:lifecyclePlan:)`
    - `init(runtimeOnlyConfiguration:lifecyclePlan:)`
  - SwiftUI adapter:
    - `View.mhAppRuntimeBootstrap(_:)`
- Full app convenience path imported through `MHPlatform`:
  - `MHAppRuntime(configuration:)`
  - `MHAppRuntimeBootstrap(configuration:lifecyclePlan:)`
  - `MHAppRuntimeBootstrap(configuration:lifecyclePlan:routePipeline:)`
- Startup APIs:
  - `startIfNeeded()`
  - `start()`
- Lifecycle shell:
  - `MHAppRuntimeTask`
  - `MHAppRuntimeLifecyclePlan`
  - `MHAppRuntimeLifecycle`
    - `handleInitialAppearance()`
    - `handleScenePhase(_:)`
  - SwiftUI adapter:
    - `View.mhAppRuntimeLifecycle(runtime:plan:)`
- Runtime state:
  - `hasStarted`
  - `premiumStatus`
  - `adsAvailability`
- Runtime-owned views:
  - `subscriptionSectionView()`
  - `nativeAdView(size:)`
  - `licensesView()`
- Preferences helper:
  - `preferenceStore`

### Threading / Actor

- `MHAppRuntime` is `@MainActor` and `@Observable`.
- `MHAppRuntimeBootstrap` is `@MainActor` and keeps runtime/lifecycle/root
  route integration on main actor.
- Startup side effects and runtime state transitions are serialized on main actor.
- `MHAppRuntimeLifecycle` is `@MainActor` and runs ordered lifecycle tasks on
  the main actor.

### Intended Call Sites

- App roots that intentionally import `MHAppRuntime` for runtime-only or
  explicit split-runtime composition
- App roots that import `MHPlatform` for the one-step default runtime path
- App launch bootstrap assembly for production / preview factories
- SwiftUI roots that want a single package-owned runtime entry point
- App foreground transitions (`scenePhase == .active`)
- SwiftUI environment injection for app-wide runtime access
- App-local startup and foreground work that should stay explicit but no longer
  repeat runtime-start coordination boilerplate
- SwiftUI roots that want MHPlatform to own the `scenePhase` observation shell

## MHDeepLinking

### Required Inputs

- `MHDeepLinkConfiguration`
- App route type conforming to `MHDeepLinkRoute`
- Incoming `URL` values from app lifecycle and external entry points
- Optional handoff primitive:
  - `MHDeepLinkInbox` (consume-once, in-memory)
  - `MHObservableDeepLinkInbox` (consume-once, main-actor observable)
  - `MHDeepLinkStore` (consume-once, persistent)
  - `MHDeepLinkSourceChain` (ordered composite source)

### Outputs

- Built deep-link URL (`url(for:transport:)`, `preferredURL(for:)`)
- Parsed route (`parse(_:)`)
- Pending URL handoff (`ingest(_:)`, `consumeLatest()`, `setPendingURL(_:)`)
- Ordered source composition:
  - `MHDeepLinkSourceChain.consumeLatestURL()`
  - `MHDeepLinkSourceChain.forwardLatestURL(to:)`
- Route-aware URL bridge helpers:
  `ingest(_:using:transport:)`, `consumeLatest(using:)`

### Threading / Actor

- `MHDeepLinkCodec` is value-typed and actor-agnostic.
- `MHDeepLinkInbox` is an `actor` and serializes latest-pending state.
- `MHObservableDeepLinkInbox` is `@MainActor` and `@Observable` while mirroring
  the latest pending URL from an underlying `MHDeepLinkInbox`.
- `MHDeepLinkStore` is `UserDefaults` backed; caller owns cross-thread usage policy.

### Intended Call Sites

- `onOpenURL`
- `scene(_:continue:)` / `NSUserActivity` resume paths
- push-notification tap handoff
- widget tap handoff
- App Intent -> app route handoff
- ordered intent + notification + in-memory source composition before route
  replay

### Boundary Rule (Normative)

- Route-aware helpers remain codec-backed bridges over URL storage/inbox
  state, including the main-actor observable inbox mirror.
- `MHDeepLinkSourceChain` remains an ordered composition shell over existing
  URL sources and does not introduce a separate queue or persistence model.
- MHPlatform does not persist app route values directly outside their encoded
  `URL` representation.

## MHRouteExecution

### Required Inputs

- Route type (`Sendable`)
- Either:
  - `MHRouteLifecycle<Route>` with app-provided logger, parse closure, and
    `applyOnMainActor` closure
  - `MHRouteExecutor<Route, Outcome>` plus `MHRouteCoordinator<Route, Outcome>`
  - identity execution path when `Route == Outcome`
- Optional resolved outcome type (`Sendable`) when the app uses
  `MHRouteExecutor` directly
- Initial readiness (`initialReadiness`) and duplicate predicate (`isDuplicate`)
- Optional latest-route handoff primitive:
  - `MHObservableRouteInbox<Route>`

### Outputs

- Higher-level lifecycle helper:
  - `MHObservableRouteInbox<Route>`
    - `pendingRoute`
    - `replacePendingRoute(_:)`
    - `registerHandler(_:)`
    - `unregisterHandler()`
    - `deliver(_:)`
    - `resynchronizePendingRoutesIfPossible()`
    - `consumeLatest()`
    - `clearPendingRoute()`
  - `hasPendingRoute`
  - `isReady`
  - `setReadiness(_:)`
  - `submit(_:applyOnMainActor:)`
  - `submit(_:parse:applyOnMainActor:)`
  - `submit(_:using:applyOnMainActor:)`
  - `submitLatest(from:parse:applyOnMainActor:)`
  - `submitLatest(from: MHDeepLinkSourceChain, parse:applyOnMainActor:)`
  - `submitLatest(from: any MHDeepLinkURLSource..., parse:applyOnMainActor:)`
  - `submitLatest(from:using:applyOnMainActor:)`
  - `submitLatest(from: MHDeepLinkSourceChain, using:applyOnMainActor:)`
  - `submitLatest(from: any MHDeepLinkURLSource..., using:applyOnMainActor:)`
  - `applyPendingIfReady(applyOnMainActor:)`
- `MHRouteExecutionOutcome<Outcome>`:
  - `.applied(Outcome)`
  - `.queued`
  - `.deduplicated`
- Pending queue introspection on `MHRouteCoordinator`:
  - `hasPendingRoute`
  - `isReady`

### Threading / Actor

- `MHRouteLifecycle` is an `actor` backed by `MHRouteCoordinator` and logs
  lifecycle outcomes through `MHLogger`.
- `MHRouteCoordinator` is an `actor`.
- Route submission, queue replacement, and apply are serialized.
- No implicit `MainActor` except the app-provided `applyOnMainActor` closure.

### Intended Call Sites

- Parsed route execution from DeepLinking and NotificationPayloads via
  `MHRouteLifecycle`
- App navigation routers/services that want logger-backed readiness gating
  without wiring `MHRouteExecutor` manually
- App-owned navigation models that want replace-latest route handoff without
  moving route meaning into MHPlatform
- Pending deep-link source drain from `MHDeepLinkInbox`,
  `MHObservableDeepLinkInbox`, or `MHDeepLinkStore`
- Ordered multi-source deep-link drain via `MHDeepLinkSourceChain` or variadic
  `submitLatest(from:...)`
- Bootstrap/readiness transitions via `setReadiness(_:)`
- Replay hook via `applyPendingIfReady()` after app state becomes ready
- Low-level coordinator usage when the app needs explicit resolve/apply
  separation or direct pending-state introspection
- Identity-route flows that already have the final route value and only need an
  app-owned `applyOnMainActor` closure

### Queue Semantics (Normative)

- Queue accepts route submission before readiness is open.
- Pending slot is latest-wins (single pending route).
- Deduplication is caller-defined via `isDuplicate`.
- If `applyPendingIfReady()` consumes pending route and `execute` fails:
  - consumed route is restored only when no newer pending route was submitted.

### Boundary Rule (Normative)

- `MHRouteLifecycle` is a thin logger-backed shell over route parsing,
  pending-source drain, readiness gating, and replay.
- Identity helpers only remove dummy resolve/apply boilerplate.
- Apps still own route definitions, route parsers, readiness decisions, and
  concrete route application logic.

## MHMutationFlow

### Required Inputs

- `MHMutation<Value>` (named operation unit)
- Optional `MHMutationRetryPolicy`
- Optional `MHCancellationHandle`
- Optional `MHMutationWorkflowConfiguration`
- Optional high-level workflow shell:
  - `MHMutationWorkflow`
- Optional post-success bridge:
  - `MHMutationAdapter<Value>` for deriving ordered steps from a successful
    app-owned mutation value
  - `MHMutationStepListBuilder` for writing ordered steps with `if` / `for`
    control flow instead of manual array mutation
  - `[MHMutationStep]` through `afterSuccess` for fixed ordered steps
- Optional success projection from an app-owned carrier value:
  - `MHMutationProjection<AdapterValue, ResultValue>` when the operation can
    emit adapter input and return value directly
  - closure-based `afterSuccess` / `returning`
  - key-path-based `adapterValue` / `resultValue`
  - semantic `value` / `followUp` key paths when an app-owned carrier returns
    value data and follow-up signals together
- Optional adapter composition through `MHMutationAdapter.appending(_:)`
- Optional inline observability through `onEvent` on `MHMutationRunner` and
  `MHMutationWorkflow.runThrowing`
- Optional logger bridge through `MHMutationLogging`
- Optional injected sleep for deterministic retry testing (`MHMutationRunner.Sleep`)

### Outputs

- Throwing workflow shell:
  - `MHMutationWorkflow.runThrowing`
    - `projection:` entry for explicit adapter/result shaping
    - `adapterValue:` convenience for fixed adapter input with unchanged result
    - `.valueAndFollowUp(value:followUp:)` projection helper for app-owned
      value + follow-up carriers
  - `MHMutationWorkflowConfiguration`
  - `MHMutationWorkflowError`
- Logger bridge:
  - `MHMutationWorkflowLogger`
- `MHMutationRun<Value>` (from `start`):
  - `events: AsyncStream<MHMutationEvent<Value>>`
  - `outcome: Task<MHMutationOutcome<Value>, Never>`
- Direct terminal `MHMutationOutcome<Value>` (from `run`)
- Event vocabulary:
  - `started`
  - `progress(.retryScheduled/.stepStarted/.stepSucceeded)`
  - `succeeded`
  - `failed`
  - `cancelled`

### Threading / Actor

- Runner is actor-agnostic.
- `MHMutationWorkflow.runThrowing` expects main-actor operations and bridges
  failure into a throwing app-facing shell.
- Events are emitted on runner execution context.
- UI observers must explicitly bridge to `MainActor`.
- `MHMutationWorkflowLogger` is a bridge over synchronous `onEvent` callbacks;
  it records through `MHLogger` without making mutation schema app-global.

### Intended Call Sites

- Save/update/delete orchestration in app workflow services
- Main-actor workflow helpers that want default failure mapping plus ordered
  post-success steps
- Fixed follow-up flows whose adapter input is stable even when the mutation
  result should be returned unchanged
- Mutation services whose success values already carry app-owned follow-up
  hints or effect metadata
- Mutation services that want to return app data and adapter input together
  without external value stores
- Mutation services that return an app-owned carrier value and only need
  key-path projection into adapter input and result value
- Mutation services that want standard requested/completed/failed/cancelled
  logging without app-local event switch boilerplate
- Retriable network + local side-effect flows
- Outcome-driven app side effects (review policy, analytics, etc.)

### Boundary Rule (Normative)

- `MHMutationAdapter` only maps a successful mutation value into ordered
  `MHMutationStep`s.
- Adapter composition preserves explicit step ordering but does not define or
  standardize the app-owned mutation schema.
- MHPlatform does not define a shared cross-app mutation outcome, hint, or
  effect model.

## MHNotificationPlans

### Required Inputs

- Candidate models (`MHReminderCandidate`, `MHSuggestionCandidate`)
- Policy models (`MHReminderPolicy`, `MHSuggestionPolicy`)
- Injected `now: Date` and `Calendar`

### Outputs

- Deterministic plan arrays:
  - `[MHReminderPlan]`
  - `[MHSuggestionPlan]`

### Threading / Actor

- Pure static planner APIs.
- No shared mutable state.
- Safe for background execution.

### Intended Call Sites

- Notification refresh pipelines on settings/candidate changes
- App launch/foreground recomputation prior to scheduling requests

### Determinism Rules (Normative)

- Same input -> same output.
- Stable sorting and identifier generation.
- No runtime randomness or system clock capture inside planners.

## MHNotificationPayloads

### Required Inputs

- Route payload models:
  - `MHNotificationPayload`
  - `MHNotificationRouteTargets`
- Response context:
  - `MHNotificationResponseContext`

### Outputs

- Payload codec (`MHNotificationPayloadCodec.encode/decode`)
- Route resolution (`MHNotificationRouteResolver.resolveRouteURL`)

### Threading / Actor

- Payload codec + route resolver are pure/sync and actor-agnostic.

### Intended Call Sites

- Payload composition and route mapping in app services.
- Shared libraries or surface adapters that only need notification route
  payload codecs.

### Boundary Rule (Normative)

- Payload composition/resolution is independent of `UNUserNotificationCenter`.
- Request construction/scheduling responsibility stays in app adapter layer.

## MHUserNotifications

### Required Inputs

- `MHNotificationPayloads` route payloads and response context.
- `MHNotificationCentering` (`UserNotifications` adapter surface).
- `MHNotificationIdentifierMatcher` (managed-request matching policy).

### Outputs

- UserNotifications descriptor bridges.
- Route delivery by closure (`MHNotificationOrchestrator.deliverRouteURL`).
- Optional orchestration outcome (`MHNotificationRequestSyncOutcome`).
- Value-typed managed request matcher (`MHNotificationIdentifierMatcher`).

### Threading / Actor

- Notification-center helpers are `MainActor`-bound.
- Route resolution and closure delivery are async and use the caller-provided
  delivery isolation.

### Intended Call Sites

- Notification adapters that register categories, request authorization,
  replace managed pending requests, or resolve notification tap payloads.

### Boundary Rule (Normative)

- `MHUserNotifications` adapts reusable payload primitives to
  `UserNotifications`; it does not own notification copy, request construction,
  scheduling policy, fallback route policy, or app route meaning.

## MHNotificationDeepLinking

### Required Inputs

- `MHUserNotifications` route delivery outcome.
- `MHDeepLinkURLDestination` (pending route handoff target).

### Outputs

- Notification route delivery into deep-link destinations.

### Threading / Actor

- Delivery follows `MHDeepLinkURLDestination` actor isolation.

### Intended Call Sites

- Notification adapters that want to store a resolved notification route in
  the same pending deep-link destination used by app route plumbing.

### Boundary Rule (Normative)

- Route delivery may target a shared deep-link destination, but the app still
  owns fallback policy, route meaning, and the chosen handoff primitive.

## MHPreferences

### Required Inputs

- Typed descriptors identified by `storageKey`:
  - `MHBoolPreferenceDescriptor`
  - `MHIntPreferenceDescriptor`
  - `MHStringPreferenceDescriptor`
  - `MHDatePreferenceDescriptor`
  - `MHCodablePreferenceDescriptor`
- Optional concrete descriptor namespace root:
  - `MHPreferenceDescriptors`
- Required `defaultSelection` on each descriptor
- Backing `UserDefaults` only when explicit DI is desired

### Outputs

- Typed reads/writes through `MHPreferenceStore`
- Codable persistence as `Data` only
- Unknown-key cleanup through `MHUserDefaultsCleanupService`
- Ordered preference migration through:
  - `MHLegacyStorageReference`
  - `MHPreferenceLifecycleService`
  - `MHPreferenceLifecycleOutcome`
  - `MHPreferenceDomainCleanupReport`
  - `MHPreferenceMigrationStep`
  - `MHPreferenceMigrationService`
  - `MHPreferenceMigrationStateDescriptor`
  - `MHPreferenceMigrationOutcome`
  - `MHPreferenceMigrationEvent`

### Threading / Actor

- Store APIs are sync and actor-agnostic.
- Follow `UserDefaults` threading guarantees.

### Intended Call Sites

- Feature flags and settings
- Lightweight app boot configuration

### Storage Rules (Normative)

- `storageKey` must be non-empty.
- Codable values are encoded to `Data`; non-`Data` decode path returns `nil`.
- `MHPreferenceStore` is the canonical non-SwiftUI access path for preference
  reads, writes, migration, and cleanup.
- `MHPreferenceDescriptors` is a concrete app-extended namespace for
  key-path-based descriptor access such as `\.notificationsEnabled`.
- Direct descriptor-based access remains supported; concrete descriptor
  overloads in `MHPreferencesUI` can infer the property type without an
  explicit type annotation.
- `.notificationsEnabled`-style shorthand aliases are app-local sugar only;
  the package does not auto-generate descriptor statics.
- Unknown-key cleanup uses caller-owned `knownDescriptors` only; the package does not
  auto-discover app descriptors.
- Unknown-key cleanup reads and writes persistent domains by explicit
  `domainName`.
- Preference migration records completed step IDs in a caller-owned
  `MHPreferenceMigrationStateDescriptor`.
- Current typed descriptors may declare legacy storage slots through
  `legacySources`.
- `MHPreferenceLifecycleService` derives migration steps from the current
  descriptor set, then prunes unknown keys from each touched domain.
- The lifecycle service treats the caller-provided current descriptor set as
  the persistence schema for cleanup; legacy sources are migrated first and are
  then eligible for removal.
- Built-in move steps read from `MHLegacyStorageReference` and only write when
  the destination descriptor is still empty.

## MHPreferencesUI

### Required Inputs

- Typed descriptors from `MHPreferences`
- SwiftUI `AppStorage`
- Optional backing `UserDefaults` for explicit store selection

### Outputs

- SwiftUI wrappers via:
  - `AppStorage` initializers for primitive and `Date` descriptors
  - `AppStorage` key-path initializers rooted at `MHPreferenceDescriptors`
  - `MHOptionalCodablePreference`
  - `MHCodablePreference`

### Threading / Actor

- Follows SwiftUI `DynamicProperty` / `AppStorage` behavior.

### Intended Call Sites

- SwiftUI view state and settings forms that need descriptor-backed bindings.

### Boundary Rule (Normative)

- `MHPreferencesUI` is a UI bridge over `MHPreferences`; it does not define
  preference key meaning, defaults, migration, cleanup, or schema policy.

## MHPersistenceMaintenance

### Required Inputs

- `MHStoreRelocationPlan`
- Optional file manager override
- Optional relocation validation hook:
  - `validateRelocatedStore(currentStoreURL, copiedFileNames)`
- Destructive reset steps (`[MHDestructiveResetStep]`)

### Outputs

- `MHStoreRelocationOutcome`
- `MHLegacyStoreCleanupOutcome`
- `MHDestructiveResetOutcome`
- `MHDestructiveResetEvent` stream via callback

### Threading / Actor

- Relocation/cleanup are synchronous file operations.
- Destructive reset orchestration is async and sequential.
- Caller owns actor hops for UI updates.

### Intended Call Sites

- Startup relocation gate before `ModelContainer`/`NSPersistentContainer`
  bootstrap
- User-triggered maintenance/reset workflow
- Developer/debug reset workflow

### Ownership Rules (Normative)

- Validation logic belongs to client app.
- When validation throws after copy:
  - copied current-store files are rolled back by the relocation service.
- The package only relocates caller-addressed store files and matching sibling
  sidecars; it does not infer app schema, container startup, or cleanup timing.
- Legacy cleanup timing remains app-owned.

## MHReviewPolicy

### Required Inputs

- `MHReviewPolicy`

### Outputs

- Pure gate decision (`shouldRequestReview(randomValue:)`)

### Threading / Actor

- `MHReviewPolicy` is pure and actor-agnostic.

### Intended Call Sites

- App-owned services that need a deterministic policy decision before choosing
  whether to adopt package requesting or flow shells

### Boundary Rule (Normative)

- `MHReviewPolicy` does not own platform requesting, logging, runtime tasks,
  mutation steps, or app-specific timing triggers.

## MHReviewRequesting

### Required Inputs

- `MHReviewPolicy`
- Optional random provider
- Optional sleep provider
- Optional outcome sink

### Outputs

- `MHReviewRequestOutcome`
- Direct requester:
  - `MHReviewRequester.requestIfNeeded(...)`

### Threading / Actor

- `MHReviewRequester.requestIfNeeded` is `@MainActor`.

### Intended Call Sites

- Direct one-off review attempts from app-owned `MainActor` coordinators
- App targets that want direct platform requesting without runtime/mutation
  workflow integration

### Boundary Rule (Normative)

- `MHReviewRequesting` owns the platform request attempt and platform fallback
  outcome, but not the app's trigger timing policy.

## MHReviewFlow

### Required Inputs

- `MHReviewPolicy`
- Optional `MHLogger`
- Optional outcome sink
- Optional random provider
- Optional sleep provider

### Outputs

- Workflow shell:
  - `MHReviewFlow`
    - `requestIfNeeded()`
    - `task(name:)`
    - `step(name:)`

### Threading / Actor

- `MHReviewFlow.requestIfNeeded` is `@MainActor`.
- Runtime-task and mutation-step closures call into the requester on the main
  actor.

### Intended Call Sites

- Post-success UX milestones (typically after `MHMutationOutcome.succeeded`)
- MainActor workflow coordinators
- Runtime/lifecycle entry points through `MHReviewFlow.task(name:)`
- Successful mutation follow-up through `MHReviewFlow.step(name:)`

### Boundary Rule (Normative)

- `MHReviewFlow` wires review requests into package-owned runtime and mutation
  shells; apps still decide which lifecycle or mutation milestones should
  trigger a review attempt.

## MHLogging

### Required Inputs

- Log policy (`MHLogPolicy`)
- Log store sinks (`[MHLogSink]`)
- Optional thin setup helper:
  `MHLoggerFactory`
- Optional metadata helper:
  `MHLogMetadata`
- Optional last-session snapshot bootstrap:
  - `MHLoggingBootstrap`
  - `snapshotStorageDescriptors`
- Logger call-site context:
  - `file` / `function` / `line`
  - `subsystem` / `category`

### Outputs

- Structured event model:
  - `MHLogEvent`
  - `MHLogLevel`
- Queryable in-memory store:
  - `MHLogStore.events(matching:)`
  - `MHLogStore.exportJSONLines(matching:)`
- Session-aware bootstrap:
  - `MHLoggingBootstrap`
  - `MHLogSessionScope`
- Sink adapters:
  - `MHOSLogSink`
- Thin logger setup helper:
  `MHLoggerFactory`
- Metadata dictionary helper:
  `MHLogMetadata`

### Threading / Actor

- `MHLogStore` is an `actor`; record/query/export/clear are serialized.
- `MHLogger` is value-typed and actor-agnostic; sync methods enqueue writes via `Task`.

### Intended Call Sites

- App startup and lifecycle diagnostics
- Mutation or workflow event tracing
- Shared app logger setup that still owns its policy/subsystem decisions locally
- JSONL export for machine-assisted analysis
- Optional last-session snapshot inspection when the app provides a storage key

### Retention Rules (Normative)

- Debug default policy keeps verbose events in memory.
- Release default policy keeps warning/error/critical events in memory.
- Ring buffer uses latest-wins eviction when capacity is exceeded.

## MHLoggingUI

### Required Inputs

- `MHLogStore` or `MHLoggingBootstrap`

### Outputs

- Reusable console UI:
  - `MHLogConsoleView`

### Threading / Actor

- Console UI fetches actor state asynchronously and updates on `MainActor`.

### Intended Call Sites

- In-app debug console and incident triage surfaces

### Boundary Rule (Normative)

- `MHLoggingUI` is an optional UI bridge over `MHLogging`; it does not own log
  capture policy, sink selection, PII masking, alerting, or telemetry backend
  contracts.

## Canonical Naming Decision

- Terminal states use `Outcome`.
- Progress streams use `Event`.
- Deterministic planner outputs use `Plan`.
- Handoff storage terms are `Inbox` / `Store` / `Queue`.
- New APIs do not add terminal `Result` naming.
