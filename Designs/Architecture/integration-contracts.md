# MHPlatform Integration Contracts

## Contract Shape

Each module contract is defined with four fields:

- `Required Inputs`
- `Outputs`
- `Threading / Actor`
- `Intended Call Sites`

This document is normative for integration design.

## MHDeepLinking

### Required Inputs

- `MHDeepLinkConfiguration`
- App route type conforming to `MHDeepLinkRoute`
- Incoming `URL` values from app lifecycle and external entry points
- Optional handoff primitive:
  - `MHDeepLinkInbox` (consume-once, in-memory)
  - `MHDeepLinkStore` (consume-once, persistent)

### Outputs

- Built deep-link URL (`url(for:transport:)`, `preferredURL(for:)`)
- Parsed route (`parse(_:)`)
- Pending URL handoff (`ingest(_:)`, `consumeLatest()`)

### Threading / Actor

- `MHDeepLinkCodec` is value-typed and actor-agnostic.
- `MHDeepLinkInbox` is an `actor` and serializes latest-pending state.
- `MHDeepLinkStore` is `UserDefaults` backed; caller owns cross-thread usage policy.

### Intended Call Sites

- `onOpenURL`
- `scene(_:continue:)` / `NSUserActivity` resume paths
- push-notification tap handoff
- widget tap handoff
- App Intent -> app route handoff

## MHRouteExecution

### Required Inputs

- Route type (`Sendable`)
- Resolved outcome type (`Sendable`)
- `MHRouteExecutor<Route, Outcome>` with app-provided `resolve/apply`
- Initial readiness (`initialReadiness`) and duplicate predicate (`isDuplicate`)

### Outputs

- `MHRouteExecutionOutcome<Outcome>`:
  - `.applied(Outcome)`
  - `.queued`
  - `.deduplicated`
- Pending route introspection:
  - `hasPendingRoute`
  - `isReady`

### Threading / Actor

- `MHRouteCoordinator` is an `actor`.
- Route submission, queue replacement, and apply are serialized.
- No implicit `MainActor`; callers hop to UI actor as needed.

### Intended Call Sites

- Parsed route execution from DeepLinking and NotificationPayloads
- Bootstrap/readiness transitions via `setReadiness(_:)`
- Replay hook via `applyPendingIfReady()` after app state becomes ready

### Queue Semantics (Normative)

- Queue accepts route submission before readiness is open.
- Pending slot is latest-wins (single pending route).
- Deduplication is caller-defined via `isDuplicate`.
- If `applyPendingIfReady()` consumes pending route and `execute` fails:
  - consumed route is restored only when no newer pending route was submitted.

## MHMutationFlow

### Required Inputs

- `MHMutation<Value>` (named operation unit)
- Optional `MHMutationRetryPolicy`
- Optional `MHCancellationHandle`
- Optional post-success steps (`[MHMutationStep]`)
- Optional injected sleep for deterministic retry testing (`MHMutationRunner.Sleep`)

### Outputs

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
- Events are emitted on runner execution context.
- UI observers must explicitly bridge to `MainActor`.

### Intended Call Sites

- Save/update/delete orchestration in app workflow services
- Retriable network + local side-effect flows
- Outcome-driven app side effects (review policy, analytics, etc.)

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

### Outputs

- Payload codec (`MHNotificationPayloadCodec.encode/decode`)
- Route resolution (`MHNotificationRouteResolver.resolveRouteURL`)
- Optional orchestration outcome (`MHNotificationRequestSyncOutcome`)

### Threading / Actor

- Payload codec + route resolver are pure/sync and actor-agnostic.
- Orchestrator bridge helpers are async and not `MainActor`-bound.

### Intended Call Sites

- Pure layer:
  - payload composition and route mapping in app services
- Bridge layer:
  - category registration, auth request, pending request sync

### Boundary Rule (Normative)

- Payload composition/resolution is independent of `UNUserNotificationCenter`.
- Request construction/scheduling responsibility stays in app adapter layer.

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

### Threading / Actor

- `MHReviewPolicy` is pure and actor-agnostic.
- `MHReviewRequester.requestIfNeeded` is `@MainActor`.

### Intended Call Sites

- Post-success UX milestones (typically after `MHMutationOutcome.succeeded`)
- MainActor workflow coordinators

## Canonical Naming Decision

- Terminal states use `Outcome`.
- Progress streams use `Event`.
- Deterministic planner outputs use `Plan`.
- Handoff storage terms are `Inbox` / `Store` / `Queue`.
- New APIs do not add terminal `Result` naming.
