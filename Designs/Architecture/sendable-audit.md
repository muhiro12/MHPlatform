# Unchecked Sendable Audit

This document tracks every intentional `@unchecked Sendable` conformance in
MHPlatform. The default rule is to prefer value types, actors, global-actor
isolation, or standard-library synchronization before adding new unchecked
conformances.

## Review Rules

- Add an entry here before introducing a new `@unchecked Sendable` conformance.
- Keep the protected mutable state and isolation rule explicit.
- Prefer removing unchecked conformances when Swift can express the same safety
  through `Sendable`, `actor`, `@MainActor`, or immutable storage.
- Treat public unchecked conformances as part of the integration contract.

## Current Inventory

### `MHAppRoutePipeline.ParseFailureBox`

Scope: private.

Safety basis: `NSLock` protects the stored failed URL.

Follow-up: keep private; consider an actor only if call sites leave main-actor
routing.

### `MHDeepLinkStore`

Scope: public.

Safety basis: stores immutable key/defaults references and delegates mutation to
`UserDefaults`.

Follow-up: keep caller-owned threading policy documented in integration
contracts.

### `MHObservableDeepLinkInbox`

Scope: public.

Safety basis: `@MainActor` isolates the observable mirror; underlying storage is
actor-backed.

Follow-up: remove unchecked if Observation can express global-actor sendability
directly.

### `MHLogRuntimeState`

Scope: public.

Safety basis: `NSLock` protects mutable capture level; level defaults are
immutable.

Follow-up: consider a tiny actor if logging call sites become async-only.

### `MHCancellationHandle`

Scope: public.

Safety basis: `NSLock` protects the cancellation flag shared across mutation
steps.

Follow-up: consider standard library synchronization when available in the
baseline.

### `MHMutationProjectionStrategy`

Scope: public.

Safety basis: stores a `@MainActor @Sendable` projection closure and exposes
main-actor projection.

Follow-up: revisit if key-path storage becomes conditionally `Sendable`.

### `MHMutationProjectionStrategy.KeyPathProjection`

Scope: private.

Safety basis: stores key paths used only through the main-actor strategy
closure.

Follow-up: remove with the parent strategy if Swift can prove key-path
sendability.

### `MHPreferenceMigrationStep.SendableUserDefaultsBox`

Scope: private.

Safety basis: boxes `UserDefaults` for synchronous migration and cleanup steps.

Follow-up: keep private; prefer descriptor/store APIs for new migration paths.

### `MHPreferenceStore`

Scope: public.

Safety basis: stores optional defaults plus locked encoder/decoder access for
Codable values.

Follow-up: keep `UserDefaults` threading policy explicit; consider split
Codable codec storage.

### `MHObservableRouteInbox`

Scope: public.

Safety basis: `@MainActor` isolates pending route and handler state.

Follow-up: remove unchecked if global-actor observable classes become directly
provable.

## Public Contract Notes

`MHDeepLinkStore` and `MHPreferenceStore` are `UserDefaults` backed. Foundation
provides the storage primitive, but app code still owns cross-process and
cross-thread policy decisions such as suite selection, write timing, and
migration ordering.

The observable inbox types are main-actor UI bridges. They should not become
background synchronization primitives; background producers should hand off
through actor-backed or URL-backed sources before entering these main-actor
mirrors.

Mutation cancellation and projection types intentionally stay lightweight because
they sit on hot workflow paths. Any replacement should preserve synchronous
cancellation reads and the current main-actor projection contract.
