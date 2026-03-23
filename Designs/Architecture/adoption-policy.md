# MHPlatform 1.0 Adoption Policy

This note defines the supported adoption posture for MHPlatform 1.0 consumers.
It covers package selection, version pinning, and the migration expectations
that app repositories should follow before cutting a stable release tag.

## Supported Version Pinning

Released consumers should use one of these pinning strategies:

- exact tag

Coordinated pre-release validation may use:

- exact revision

MHPlatform release automation publishes short tags such as `1.0` and `1.1`
from pushes to `main`. Those tags are intended for exact tag pinning, not
SwiftPM semantic-version requirements.

`branch: "main"` is not a supported 1.0 adoption strategy.
Using the moving main branch bypasses the package-owned consumer contract and
turns every downstream build into an implicit integration test.

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

See [Consumer Boundaries](./consumer-boundaries.md) for the normative product
matrix.

## Shared Library Migration Rule

If a shared package currently depends on `MHPlatform` but only imports
core-safe APIs such as:

- `MHDeepLinking`
- `MHPreferences`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHLogging`

it should migrate to `MHPlatformCore`.

Do not keep the full `MHPlatform` umbrella in a shared library only because an
app target happens to use it elsewhere.

## Advanced Runtime Migration Rule

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

## Optional Shell Rule

- `MHAppRoutePipeline` and `mhRouteHandler` are optional route shells.
- `MHMutationWorkflow` is an optional mutation shell.
- `MHReviewFlow` is an optional review shell.

Apps should add these shells only in the targets that own those concerns.
They are not part of the minimum runtime/bootstrap baseline.

## Adoption Checklist For App Repositories

1. Pick the base product from the consumer matrix before adding imports.
2. Remove `branch: "main"` adoption before a stable 1.0 rollout.
3. Pin the package to an exact tag or coordinated exact revision.
4. Move shared libraries off `MHPlatform` when they only need core-safe APIs.
5. Keep app-specific route meaning, preference meaning, mutation semantics, and
   notification semantics outside MHPlatform.

## Out Of Scope For This Run

- Editing downstream app repositories
- Updating existing package pins in app repositories
- Preserving pre-1.0 compatibility aliases for incorrect adoption
