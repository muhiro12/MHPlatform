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

- `MHAppConfiguration`
  - `subscriptionProductIDs`
  - `subscriptionGroupID`
  - `nativeAdUnitID`
  - `preferencesSuiteName`
  - `showsLicenses`
- Optional route bootstrap primitive:
  - `MHAppRoutePipeline<Route>`
  - app-owned lifecycle placement for `routePipeline.task(name:)`

### Outputs

- Bootstrap shell:
  - `MHAppRuntimeBootstrap`
    - `runtime`
    - `lifecyclePlan`
    - `routeInbox`
    - `makeLifecycle()`
  - SwiftUI adapter:
    - `View.mhAppRuntimeBootstrap(_:)`
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
- Optional adapter composition through `MHMutationAdapter.appending(_:)`
- Optional inline observability through `onEvent` on `MHMutationRunner` and
  `MHMutationWorkflow.runThrowing`
- Optional injected sleep for deterministic retry testing (`MHMutationRunner.Sleep`)

### Outputs

- Throwing workflow shell:
  - `MHMutationWorkflow.runThrowing`
    - `projection:` entry for explicit adapter/result shaping
    - `adapterValue:` convenience for fixed adapter input with unchanged result
  - `MHMutationWorkflowConfiguration`
  - `MHMutationWorkflowError`
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
- Optional bridge dependency:
  - `MHNotificationCentering` (`UserNotifications` adapter surface)
  - `MHDeepLinkURLDestination` (pending route handoff target)
  - `MHNotificationIdentifierMatcher` (managed-request matching policy)

### Outputs

- Payload codec (`MHNotificationPayloadCodec.encode/decode`)
- Route resolution (`MHNotificationRouteResolver.resolveRouteURL`)
- Route delivery (`MHNotificationOrchestrator.deliverRouteURL`)
- Optional orchestration outcome (`MHNotificationRequestSyncOutcome`)
- Value-typed managed request matcher (`MHNotificationIdentifierMatcher`)

### Threading / Actor

- Payload codec + route resolver are pure/sync and actor-agnostic.
- Orchestrator bridge helpers are async and not `MainActor`-bound.

### Intended Call Sites

- Pure layer:
  - payload composition and route mapping in app services
- Bridge layer:
  - category registration, auth request, pending request sync, notification tap handoff

### Boundary Rule (Normative)

- Payload composition/resolution is independent of `UNUserNotificationCenter`.
- Request construction/scheduling responsibility stays in app adapter layer.
- Route delivery may target a shared deep-link destination, but the app still owns
  fallback policy and the chosen handoff primitive.

## MHPreferences

### Required Inputs

- Typed keys with namespace:
  - `MHBoolPreferenceKey`
  - `MHIntPreferenceKey`
  - `MHStringPreferenceKey`
  - `MHCodablePreferenceKey`
- Backing `UserDefaults`

### Outputs

- Typed reads/writes through `MHPreferenceStore`
- Codable persistence as `Data` only
- SwiftUI bridges via `AppStorage` initializers for primitive keys

### Threading / Actor

- Store APIs are sync and actor-agnostic.
- Follow `UserDefaults` threading guarantees.

### Intended Call Sites

- Feature flags and settings
- Lightweight app boot configuration

### Storage Rules (Normative)

- Fully qualified storage key is `"\(namespace).\(name)"`.
- Namespace/name must be non-empty.
- Codable values are encoded to `Data`; non-`Data` decode path returns `nil`.

## MHPersistenceMaintenance

### Required Inputs

- `MHStoreMigrationPlan`
- Optional file manager override
- Optional migration validation hook:
  - `validateMigration(currentStoreURL, copiedFileNames)`
- Destructive reset steps (`[MHDestructiveResetStep]`)

### Outputs

- `MHStoreMigrationOutcome`
- `MHStoreLegacyCleanupOutcome`
- `MHDestructiveResetOutcome`
- `MHDestructiveResetEvent` stream via callback

### Threading / Actor

- Migration/cleanup are synchronous file operations.
- Destructive reset orchestration is async and sequential.
- Caller owns actor hops for UI updates.

### Intended Call Sites

- Startup migration gate before model container/bootstrap
- User-triggered maintenance/reset workflow

### Validation Hook Rule (Normative)

- Validation logic belongs to client app.
- When validation throws after copy:
  - copied current-store files are rolled back by migrator.

## MHReviewPolicy

### Required Inputs

- `MHReviewPolicy`
- Optional random provider
- Optional sleep provider

### Outputs

- `MHReviewRequestOutcome`
- Pure gate decision (`shouldRequestReview(randomValue:)`)
- Workflow shell:
  - `MHReviewFlow`
    - `requestIfNeeded()`
    - `task(name:)`
    - `step(name:)`

### Threading / Actor

- `MHReviewPolicy` is pure and actor-agnostic.
- `MHReviewRequester.requestIfNeeded` is `@MainActor`.

### Intended Call Sites

- Post-success UX milestones (typically after `MHMutationOutcome.succeeded`)
- MainActor workflow coordinators
- Runtime/lifecycle entry points through `MHReviewFlow.task(name:)`
- Successful mutation follow-up through `MHReviewFlow.step(name:)`

## MHLogging

### Required Inputs

- Log policy (`MHLogPolicy`)
- Log store sinks (`[MHLogSink]`)
- Optional thin setup helper:
  `MHLoggerFactory`
- Logger call-site context:
  - `file` / `function` / `line`
  - `subsystem` / `category`
- Optional JSONL sink configuration:
  - `fileURL`
  - `maximumFileSizeBytes`

### Outputs

- Structured event model:
  - `MHLogEvent`
  - `MHLogLevel`
- Queryable in-memory store:
  - `MHLogStore.events(matching:)`
  - `MHLogStore.exportJSONLines(matching:)`
- Sink adapters:
  - `MHOSLogSink`
  - `MHJSONLLogSink`
- Thin logger setup helper:
  `MHLoggerFactory`
- Reusable console UI:
  - `MHLogConsoleView`

### Threading / Actor

- `MHLogStore` is an `actor`; record/query/export/clear are serialized.
- `MHJSONLLogSink` is an `actor`; append/rotation/load are serialized.
- `MHLogger` is value-typed and actor-agnostic; sync methods enqueue writes via `Task`.
- Console UI fetches actor state asynchronously and updates on `MainActor`.

### Intended Call Sites

- App startup and lifecycle diagnostics
- Mutation or workflow event tracing
- Shared app logger setup that still owns its policy/subsystem decisions locally
- In-app debug console and incident triage
- JSONL export for machine-assisted analysis

### Retention Rules (Normative)

- Debug default policy keeps verbose events and enables JSONL persistence.
- Release default policy keeps warning/error/critical events and disables JSONL persistence.
- Ring buffer uses latest-wins eviction when capacity is exceeded.
- JSONL sink rotates to a single archive file when byte cap is exceeded.

## Canonical Naming Decision

- Terminal states use `Outcome`.
- Progress streams use `Event`.
- Deterministic planner outputs use `Plan`.
- Handoff storage terms are `Inbox` / `Store` / `Queue`.
- New APIs do not add terminal `Result` naming.
