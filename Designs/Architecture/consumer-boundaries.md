# MHPlatform Consumer Boundaries

This note is the normative 1.x consumer matrix for MHPlatform.
Use it to decide which product each adopter should depend on before adding any
module import.
For product-selection rationale and current selection rules, pair it with
[adoption-policy.md](./adoption-policy.md).

## Consumer Matrix

| Consumer type | Typical targets | Primary product | Add only when needed | Avoid by default |
| --- | --- | --- | --- | --- |
| Full-platform app target | `FooApp`, `FooWatch`, other UI/composition roots that want the full platform surface | `MHPlatform` | `MHAppRoutePipeline` / `mhRouteHandler`, `MHMutationWorkflow`, `MHReviewFlow`, `MHPlatformTesting` in tests | Direct split runtime bundles unless custom composition is intentional |
| Advanced app runtime target | App root that wants runtime, lifecycle, environment injection, and optional route plumbing without the full umbrella | `MHAppRuntime` | `MHAppRuntimeDefaults`, `MHAppRuntimeAds`, `MHAppRuntimeLicenses`, `MHMutationFlow`, `MHReviewPolicy`, concrete core modules | Pulling `MHPlatform` only to reach bootstrap helpers when the narrower runtime surface is intentional |
| Shared logic package / shared library | `FooLibrary`, watch-capable shared logic package, reusable package target | `MHPlatformCore` or granular core-safe modules | Concrete modules such as `MHDeepLinking`, `MHPreferences`, `MHNotificationPlans`, `MHPersistenceMaintenance` | `MHPlatform`, `MHAppRuntime`, `MHReviewPolicy` |
| Granular core-safe consumer | Target that only needs one focused concern | Concrete module product | `MHPlatformTesting` in tests | Umbrellas when a single module is enough |
| Optional shell adopter | App target already on one of the app-facing paths above | `MHAppRoutePipeline` / `mhRouteHandler`, `MHMutationWorkflow`, `MHReviewFlow` | Keep app-owned route meaning, mutation semantics, and review policy inputs outside MHPlatform | Treating route, review, or mutation shells as mandatory platform baseline |

## Supported Entry Point Tiers

Default pillars:

- `MHPlatform`
- `MHPlatformCore`

Advanced app surface:

- `MHAppRuntime`

Testing support:

- `MHPlatformTesting`

Advanced composition surfaces:

- split runtime bundles: `MHAppRuntimeDefaults`, `MHAppRuntimeAds`,
  `MHAppRuntimeLicenses`
- concrete modules: `MHDeepLinking`, `MHLogging`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHRouteExecution`, `MHPersistenceMaintenance`,
  `MHPreferences`
- opt-in workflow shells: `MHMutationFlow`, `MHReviewPolicy`

Start from a documented public entry point unless the target is intentionally doing
advanced composition around one focused concern.

## Normative Rules

- `MHPlatform` is the full umbrella for app composition targets that
  intentionally want runtime, workflow shells, and the shared core surface from
  one product.
- `MHPlatformCore` is the shared-package umbrella. It is the default umbrella
  for shared packages and shared libraries.
- `MHAppRuntime` is the advanced app-root surface for runtime/bootstrap-only
  apps and explicit split-runtime-bundle composition.
- `MHPlatform` remains the only one-step default runtime path. Keep the full
  umbrella when the target wants package-owned StoreKit, ads, or license
  integrations without manual composition.
- Split runtime bundles and concrete modules are advanced composition tools,
  not the default onboarding path for new adopters.
- Route, review, and mutation shells are optional. Apps adopt them only when
  that concern exists in the target.
- Shared packages must not depend on `MHPlatform`, `MHAppRuntime`, or
  `MHReviewPolicy`. Shared packages should stop at `MHPlatformCore` or granular
  core-safe modules unless a focused standalone product is genuinely required.

## What Stays App-Owned

- Route enum meaning and navigation destination meaning
- Notification copy and presentation meaning
- Planner business semantics
- Persistence schema meaning and validation
- Preference key meaning and defaults
- Domain mutation result and effect meaning
- Other app-specific business semantics

## Consumer Selection Checklist

1. Is this a UI/composition root that wants the full shared platform surface?
   Use `MHPlatform`.
2. Is this an app root that wants runtime/bootstrap mechanics or explicit
   runtime composition without the full umbrella?
   Use `MHAppRuntime`.
3. Is this a shared package or shared library?
   Use `MHPlatformCore` or a concrete module.
4. Is the target only adding route, mutation, or review workflow shells?
   Add those shells explicitly instead of switching umbrellas.
5. Does the app want package-owned StoreKit, ads, or license integrations
   without the full umbrella?
   Add the split runtime bundles explicitly on top of `MHAppRuntime`.

## Evidence Paths

- Full umbrella example app: `Example/MHPlatformExample/`
- Shared-library consumer fixture: `Fixtures/Consumers/SharedLibraryConsumer/`
- Runtime-only consumer fixture: `Fixtures/Consumers/RuntimeOnlyConsumer/`
- Explicit split-runtime consumer fixture:
  `Fixtures/Consumers/SplitRuntimeConsumer/`
- Optional-shell consumer fixture: `Fixtures/Consumers/OptionalShellConsumer/`
- Shared-package-safe umbrella tests: `Tests/MHPlatformCoreTests/`
- Full umbrella tests: `Tests/MHPlatformTests/`
- Runtime split composition tests: `Tests/MHAppRuntimeTests/`
- CI consumer fixture build task: `ci_scripts/tasks/test_consumer_fixtures.sh`
