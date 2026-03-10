# MHPlatform Architecture Guide

## Scope

This guide defines the strict `platform-in-package, app-as-adapter` policy for
this repository.

Related documents:

- [architecture.md](./architecture.md)
- [integration-contracts.md](./integration-contracts.md)

## Responsibility Boundaries

| Layer | Owns | Must not own |
| --- | --- | --- |
| Package modules (`MHAppRuntime`, `MHDeepLinking`, `MHMutationFlow`, and related targets) | Reusable non-domain runtime/bootstrap, route handoff primitives, workflow shells, logging, preferences, persistence maintenance | App-specific route enums, domain models, success metadata schemas, presentation meaning, widget or watch policy |
| App adapters (adopting app targets, notifications, widgets, App Intents) | Configuration assembly, Apple framework integration, route definitions, side-effect orchestration, mapping app-owned outcomes into package primitives | Forked copies of package orchestration or shared package policy |
| Views and navigation shells | Presentation state, formatting, navigation binding, app-specific UI composition | Runtime bootstrap assembly, reusable workflow rules, deep-link parsing policy, mutation retry policy |

## App Integration Rules

Allowed in app adapters:

- Assemble `MHAppConfiguration` and other app-owned package inputs
- Wire app services around `MHAppRuntimeBootstrap`, `MHRouteLifecycle`,
  `MHMutationWorkflow`, and `MHReviewFlow`
- Map app-owned route and mutation result types into package primitives
- Perform Apple-framework side effects after package-owned workflows complete

Not allowed in app adapters:

- App-local copies of runtime bootstrap, route replay, or mutation sequencing
- New package policy hidden behind app-specific wrapper layers
- Persisting app route values in package-owned storage outside encoded `URL`
  representations
- Moving app-specific side-effect decisions into the umbrella `MHPlatform`
  target

## Canonical Runtime Flow

`App composition root -> MHAppRuntimeBootstrap -> MHAppRuntimeLifecyclePlan -> app-owned tasks and route apply closures`

The app owns concrete services, identifiers, and side effects.
MHPlatform owns the reusable bootstrap and lifecycle shells.

## Canonical Deep-Link Flow

`External URL / notification tap / App Intent -> app-owned route type + MHDeepLinkCodec -> MHAppRoutePipeline or MHRouteLifecycle -> app-owned apply closure`

MHPlatform may buffer and replay encoded route URLs, but route meaning stays in
the app.

## Canonical Mutation Flow

`View / App Intent -> app-owned mutation service -> MHMutationWorkflow -> app-owned adapter bridge -> app-side side effects`

MHPlatform owns retry, cancellation, ordered post-success execution, and review
trigger helpers.
Apps still own the mutation result schema and follow-up policy.

## Boundary Rules

- Keep `MHPlatform` as a thin convenience umbrella over concrete modules.
- Add reusable behavior to named modules, not to app-specific wrappers.
- Keep app-specific route types, notification text, mutation metadata, and
  side-effect policy outside the package.
- Prefer additive package-owned shells when the same integration shape appears
  in at least two apps.

## Current Design Pressure

1. Runtime adoption should converge on `MHAppRuntimeBootstrap` rather than
   handwritten bootstrap wrappers.
2. Route handoff should prefer `MHDeepLinkInbox`, `MHDeepLinkStore`,
   `MHObservableRouteInbox`, and `MHRouteLifecycle` over app-local pending
   route queues.
3. Mutation follow-up should use `MHMutationAdapter` and `MHMutationWorkflow`
   without standardizing app-specific success schemas.
4. Logging setup should use `MHLoggerFactory` while keeping subsystem,
   category, and sink policy app-owned.
