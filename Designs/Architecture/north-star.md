# MHKit North Star

MHKit is an application infrastructure kit for SwiftUI/SwiftData apps.
It provides reusable primitives for app plumbing, not app domain behavior.

## Product Intent

- Extract duplicated infrastructure from real apps (Incomes, Cookle).
- Keep APIs small, composable, and Swift-concurrency friendly.
- Keep behavior deterministic and testable.
- Keep module boundaries explicit so adoption can be incremental.

## Non-Goals

- No domain rules in MHKit (`finance`, `recipe`, etc. stay in app/domain layers).
- No generic SwiftData abstraction layer (no repositories, no persistence facade).
- No global singleton runtime that hides threading or lifecycle ownership.

## Canonical Vocabulary

| Term | Meaning | MHKit Examples |
| --- | --- | --- |
| `Outcome` | Terminal async/sync end state used by workflows | `MHRouteExecutionOutcome`, `MHMutationOutcome`, `MHNotificationRequestSyncOutcome`, `MHStoreMigrationOutcome` |
| `Event` | Ordered progress signal emitted while running | `MHMutationEvent`, `MHDestructiveResetEvent` |
| `Plan` | Pure deterministic planning output with no side effect | `MHReminderPlan`, `MHSuggestionPlan` |
| `Inbox` | Consume-once handoff slot (latest only) | `MHDeepLinkInbox` |
| `Store` | Durable persistence-backed handoff slot | `MHDeepLinkStore`, `MHPreferenceStore` |
| `Queue` | Backlog behavior with ordering/replacement semantics | `MHRouteCoordinator` pending route (latest-wins) |

## Error and Recoverability Rules

- `Outcome.failed(..., isRecoverable: Bool)` is used when caller-side policy decisions are expected (`MHMutationOutcome`).
- Deterministic pure planners should not hide failures; invalid inputs are filtered or rejected at input boundary.
- Route execution failure keeps pending route when appropriate (`applyPendingIfReady` re-queues consumed route if no newer pending route exists).

## Module Ownership

| Capability | Owned by MHKit | Not Owned by MHKit |
| --- | --- | --- |
| Deep link parsing/handoff | URL codec + inbox/store | App route enums, screen selection state |
| Route execution | readiness-gated execution + latest-wins pending queue | URL parsing, domain interpretation |
| Notification planning | deterministic candidate -> plan transforms | UN scheduling policy and app-specific copy |
| Notification payload routing | payload codec + response route resolving + optional bridge helpers | App notification-center adoption strategy |
| Mutation orchestration | retry/cancel/event/outcome primitive | Domain mutation meaning and business validation |
| Persistence maintenance | migration/reset orchestration | App-specific schema validation and data rules |
| Preferences | typed keys + AppStorage bridges + codable-as-Data | Feature semantics for each key |
| Review request policy | lottery + delayed request orchestration | Product timing/eligibility strategy |

## Decision Matrix

| Question | If Yes | If No |
| --- | --- | --- |
| Is behavior tied to domain entities/rules? | Domain library or app module | Continue check |
| Is this platform adapter glue for one target only? | App adapter layer | Continue check |
| Is this cross-app infra with stable contract and no domain ownership? | MHKit | Keep local to app |

## Concurrency and State Rules

- Prefer value types and explicit actors.
- Do not hide mutable global state.
- Expose threading expectations in each contract:
  - actor-isolated primitives (`MHRouteCoordinator`, `MHDeepLinkInbox`)
  - caller-thread pure functions (`MHReminderPlanner`, `MHSuggestionPlanner`)
  - explicit `MainActor` API where UI platform requires it (`MHReviewRequester`).

## Adoption Posture

- Breaking changes are acceptable during pre-release.
- API coherence is prioritized over temporary compatibility aliases.
- Documentation in `Designs/Architecture` is the source of integration truth.
