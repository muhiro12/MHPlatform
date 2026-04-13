# MHPlatform Consumer Adoption

This note summarizes current product-selection rules for MHPlatform consumers.
`1.x` is treated as beta, so adopters should follow the current public surface
instead of expecting upgrade-specific compatibility layers or historical
fallback shells inside MHPlatform.

## Consumer Rules

- App composition targets that want the full platform surface may adopt
  `MHPlatform`.
- App targets that want a narrower runtime/bootstrap foundation may adopt
  `MHAppRuntime`.
- Shared packages and shared libraries should adopt `MHPlatformCore` or
  granular core-safe modules.
- Route, mutation, and review shells remain opt-in additions. They do not
  change the base product recommendation for a target.

Supported default pillars:

- `MHPlatform`
- `MHPlatformCore`

Advanced public app path:

- `MHAppRuntime`

Advanced composition surfaces that should not be the default onboarding path:

- split runtime bundles: `MHAppRuntimeDefaults`, `MHAppRuntimeAds`,
  `MHAppRuntimeLicenses`
- concrete modules: `MHDeepLinking`, `MHLogging`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHRouteExecution`, `MHPersistenceMaintenance`,
  `MHPreferences`
- opt-in workflow shells: `MHMutationFlow`, `MHReviewPolicy`

See [Consumer Boundaries](./consumer-boundaries.md) for the consumer product
matrix.

## Shared Library Selection Rule

If a shared package only imports core-safe APIs such as:

- `MHDeepLinking`
- `MHPreferences`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHLogging`

it should adopt `MHPlatformCore`.

Do not keep the full `MHPlatform` umbrella in a shared library only because an
app target happens to use it elsewhere.

## Advanced Runtime Selection Rule

If an app target only needs:

- `MHAppRuntimeBootstrap`
- `MHAppRuntimeLifecycle`
- `View.mhAppRuntimeBootstrap(_:)`
- `View.mhAppRuntimeEnvironment(_:)`
- optional route plumbing from `MHAppRoutePipeline`

it should adopt `MHAppRuntime`.

Add `MHAppRuntimeDefaults`, `MHAppRuntimeAds`, and `MHAppRuntimeLicenses`
explicitly only when the target wants those package-owned integrations without
moving to the full `MHPlatform` umbrella.

## Current Shell Preferences

- Prefer `MHAppRuntimeBootstrap` as the default root entry point for new app
  composition.
- Prefer `MHAppRoutePipeline` when the root owns route ingestion and pending
  route drain wiring.
- Prefer `MHReviewFlow` for review-trigger orchestration instead of rebuilding
  requester/task glue in app code.
- Use `View.mhAppRuntimeEnvironment(_:)` for previews and tests that should not
  start lifecycle tasks.
- Keep lower-level primitives only when the app genuinely needs custom
  composition.

## Optional Shell Rule

- `MHAppRoutePipeline` and `mhRouteHandler` are optional route shells.
- `MHMutationWorkflow` is an optional mutation shell.
- `MHReviewFlow` is an optional review shell.

Apps should add these shells only in the targets that own those concerns.
They are not part of the minimum runtime/bootstrap baseline.

## Adoption Checklist For App Repositories

1. Pick the base product from the consumer matrix before adding imports.
2. Prefer the current documented shells instead of keeping app-local
   integration glue for historical adoption paths.
3. Keep app-specific route meaning, preference meaning, mutation semantics, and
   notification semantics outside MHPlatform.

## Out Of Scope For This Run

- Editing downstream app repositories
- Preserving upgrade-specific compatibility layers or historical fallback shells
  inside MHPlatform
