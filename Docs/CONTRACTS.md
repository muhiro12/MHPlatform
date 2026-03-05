# MHKit Integration Contracts

## How to Read Contracts

Each module contract is defined with the same four fields:

- `Required Inputs`:
  models, callbacks, clocks, stores, and adapters the caller must provide.
- `Outputs`:
  values, plans, outcomes, events, and side-effect signals produced by the
  module.
- `Threading/Actor`:
  actor guarantees and caller responsibilities for MainActor or background
  execution.
- `Intended Call Sites`:
  where the module should be invoked in app lifecycle or workflow wiring.

## MHDeepLinking

### Required Inputs

- `MHDeepLinkConfiguration` for URL grammar policy.
- App route type conforming to `MHDeepLinkRoute`.
- Incoming `URL` values from app lifecycle, intents, widgets, or notifications.
- Optional handoff storage choice:
  `MHDeepLinkInbox` for in-memory handoff, `MHDeepLinkStore` for durable
  handoff.

### Outputs

- Built deep-link `URL` values from route descriptors.
- Parsed route values from incoming URLs.
- Consume-once pending URL handoff via inbox or store.

### Threading/Actor

- `MHDeepLinkCodec` is a value type and has no MainActor requirement.
- `MHDeepLinkInbox` is an actor and serializes pending URL access.
- `MHDeepLinkStore` is `UserDefaults` backed; caller chooses synchronization
  strategy if accessed from multiple executors.

### Intended Call Sites

- `onOpenURL` and equivalent lifecycle URL entry points.
- Cold-start replay when app resumes from external entry points.
- Intent/notification handoff where URL capture and later consumption are
  needed.

## MHNotificationPlans

### Required Inputs

- Pure candidate models:
  `MHReminderCandidate` or `MHSuggestionCandidate`.
- Planning policy:
  `MHReminderPolicy` or `MHSuggestionPolicy`.
- Caller-provided `now: Date` and `Calendar` for deterministic planning.

### Outputs

- Deterministic arrays of plan models:
  `[MHReminderPlan]` and `[MHSuggestionPlan]`.
- Stable identifiers and route URLs suitable for downstream payload/scheduling
  layers.

### Threading/Actor

- Planners are pure static functions with caller-defined threading.
- Safe to run off-main for notification refresh or background recomputation.
- No internal actor or shared mutable state.

### Intended Call Sites

- Notification refresh workflows when candidates or settings change.
- App launch or foreground refresh before scheduling requests.
- Domain-to-adapter boundary where pure planning feeds platform schedulers.

## MHNotificationPayloads

### Required Inputs

- Route payload models:
  `MHNotificationPayload`, `MHNotificationRouteTargets`.
- Response context and descriptors:
  `MHNotificationResponseContext`, `MHNotificationActionDescriptor`,
  `MHNotificationCategoryDescriptor`.
- Optional notification-center bridge:
  `MHNotificationCentering` for orchestrator helpers.

### Outputs

- Encoded/decoded `userInfo` dictionaries via `MHNotificationPayloadCodec`.
- Resolved route URL from notification response metadata.
- Managed request synchronization summary via
  `MHNotificationRequestSyncResult`.

### Threading/Actor

- Codec and resolver APIs are synchronous and actor-agnostic.
- Orchestrator async helpers are not MainActor-bound.
- Caller controls UI hops when resolved routes need presentation updates.

### Intended Call Sites

- Notification category registration at startup.
- Notification authorization and pending-request sync workflows.
- Notification response handling to map actions into route URLs.

## MHMutationFlow

### Required Inputs

- Primary mutation operation closure.
- Optional retry policy (`MHMutationRetryPolicy`) and cancellation handle
  (`MHCancellationHandle`).
- Ordered post-success steps (`[MHMutationStep]`) and optional event callback.

### Outputs

- Terminal workflow result:
  `MHMutationOutcome<Value>`.
- Progress stream through `MHMutationEvent` callback.
- Completed-step names for observability and post-run diagnostics.

### Threading/Actor

- Runner is async and actor-agnostic; caller chooses execution context.
- Event callback executes on runner context; UI observers must hop to
  `MainActor`.
- Cancellation observes both `Task` cancellation and explicit handle state.

### Intended Call Sites

- App workflow services that combine mutation and side effects.
- Save/update/delete flows that require retry and deterministic cleanup.
- Post-success orchestration pipelines (widget reload, notification sync, etc.).

## MHRouteExecution

### Required Inputs

- App route type and resolved outcome type (both `Sendable`).
- Readiness callback (`isReady`) describing app apply readiness.
- Resolve/apply closures via `MHRouteExecutor`.

### Outputs

- Immediate apply or queued result via `MHRouteResolution<Outcome>`.
- Latest-wins pending route state exposed by coordinator APIs.

### Threading/Actor

- `MHRouteCoordinator` is an actor and serializes handle/apply operations.
- Resolve and apply closures run asynchronously and may hop actors internally.
- No implicit MainActor behavior; caller decides where presentation state
  updates occur.

### Intended Call Sites

- Deep-link and notification route entry handling.
- Readiness replay flows (`applyPendingIfNeeded`) after bootstrap completes.
- Route pipelines where resolve and apply concerns should remain explicit.

## MHPersistenceMaintenance

### Required Inputs

- Migration plan (`MHStoreMigrationPlan`) and optional `FileManager`.
- Ordered destructive reset steps (`[MHDestructiveResetStep]`).
- Optional reset event sink callback.

### Outputs

- Migration and cleanup results:
  `MHStoreMigrationResult`, `MHStoreLegacyCleanupResult`.
- Reset execution outputs:
  `MHDestructiveResetOutcome` plus `MHDestructiveResetEvent` stream.

### Threading/Actor

- Store migration/cleanup APIs are synchronous file operations; off-main usage
  is preferred.
- Reset service is async and caller-thread controlled.
- Event callback is invoked in reset execution context.

### Intended Call Sites

- Startup migration gates before model container or app data bootstrap.
- User-triggered maintenance and destructive reset workflows.
- Debug tooling that requires deterministic reset sequencing.

## MHPreferences

### Required Inputs

- Typed keys:
  `MHBoolPreferenceKey`, `MHIntPreferenceKey`, `MHStringPreferenceKey`,
  `MHCodablePreferenceKey`.
- Backing `UserDefaults` store (`.standard` or app-group suite).
- Optional `AppStorage` binding use for SwiftUI integration.

### Outputs

- Typed read/write access for primitive and codable values.
- Key removal and codable data encoding/decoding behavior.
- SwiftUI `AppStorage` bridges for primitive key types.

### Threading/Actor

- Store APIs are synchronous and have no MainActor requirement.
- Underlying `UserDefaults` thread-safety follows Apple behavior.
- SwiftUI `AppStorage` usage should follow view-layer MainActor expectations.

### Intended Call Sites

- Settings and feature-flag reads/writes.
- App bootstrap for user-configurable behavior.
- Lightweight shared preferences used across app targets.

## MHReviewPolicy

### Required Inputs

- `MHReviewPolicy` containing lottery range and optional request delay.
- Random value provider and sleep closure overrides (for testing or policy
  control).
- Foreground scene availability on iOS live path.

### Outputs

- Terminal review workflow result:
  `MHReviewRequestOutcome`.
- Pure policy decision via `MHReviewPolicy.shouldRequestReview(randomValue:)`.

### Threading/Actor

- `MHReviewPolicy` is actor-agnostic and pure.
- `MHReviewRequester.requestIfNeeded` is `@MainActor`.
- iOS live request path depends on foreground scene and StoreKit request API.

### Intended Call Sites

- Post-success app workflows where review prompts are eligible.
- Feature completion milestones where lottery gating is needed.
- MainActor orchestration layers that already manage UI-side effects.

## Naming Convention Decision

- Terminal async workflow types:
  prefer `...Outcome`.
- Progress stream types:
  prefer `...Event`.
- `...Result` compatibility:
  keep existing `Result` types for current low-level/sync surfaces; avoid adding
  new terminal async `Result` types.
- Planner pattern:
  `...Planner.build(...) -> [...Plan]`.
- Handoff storage terms:
  `Inbox` for consume-once handoff, `Store` for durable persistence,
  `Queue` for ordered multi-item backlog.

## Optional Alignment Proposal (Doc-only)

- Proposal:
  converge future long-running APIs on `Outcome` plus optional `Event` stream.
- Rationale:
  this matches existing `MHMutationFlow` and `MHPersistenceMaintenance` shapes
  and reduces cross-module adoption friction.
- Migration policy:
  non-breaking and documentation-only in this run; no source API changes.
