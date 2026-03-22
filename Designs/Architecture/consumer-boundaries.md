# MHPlatform Consumer Boundaries

This note is the normative 1.0 consumer matrix for MHPlatform.
Use it to decide which product each adopter should depend on before adding any
module import.

## Consumer Matrix

| Consumer type | Typical targets | Primary product | Add only when needed | Avoid by default |
| --- | --- | --- | --- | --- |
| Full-platform app target | `FooApp`, `FooWatch`, other UI/composition roots that want the full platform surface | `MHPlatform` | `MHAppRoutePipeline` / `mhRouteHandler`, `MHMutationWorkflow`, `MHReviewFlow`, `MHPlatformTesting` in tests | Direct split runtime bundles unless custom composition is intentional |
| Default-runtime app target | App root that wants runtime-owned StoreKit, ads, or license views without the full umbrella | `MHAppRuntime` | `MHMutationFlow`, `MHReviewPolicy`, concrete core modules | `MHPlatform` when the app does not need the convenience umbrella |
| Runtime/bootstrap-only app target | App root that only needs runtime, lifecycle, environment injection, and optional route plumbing | `MHAppRuntimeCore` | `MHAppRuntimeDefaults`, `MHAppRuntimeAds`, `MHAppRuntimeLicenses`, `MHMutationFlow`, `MHReviewPolicy` | `MHAppRuntime` until the app actually needs package-owned defaults |
| Shared logic package / shared library | `FooLibrary`, watch-capable shared logic package, reusable package target | `MHPlatformCore` or granular core-safe modules | Concrete modules such as `MHDeepLinking`, `MHPreferences`, `MHNotificationPlans`, `MHPersistenceMaintenance` | `MHPlatform`, `MHAppRuntime`, `MHReviewPolicy` |
| Granular core-safe consumer | Target that only needs one focused concern | Concrete module product | `MHPlatformTesting` in tests | Umbrellas when a single module is enough |
| Optional shell adopter | App target already on one of the app-facing paths above | `MHAppRoutePipeline` / `mhRouteHandler`, `MHMutationWorkflow`, `MHReviewFlow` | Keep app-owned route meaning, mutation semantics, and review policy inputs outside MHPlatform | Treating route, review, or mutation shells as mandatory platform baseline |

## Normative Rules

- `MHPlatform` is the full umbrella for app composition targets that
  intentionally want runtime, workflow shells, and the shared core surface from
  one product.
- `MHPlatformCore` is the shared-package umbrella. It is the default umbrella
  for shared packages and shared libraries.
- `MHAppRuntimeCore` is the lightweight 1.0 path for runtime/bootstrap-only
  apps. It is already the supported answer for avoiding StoreKit, ads, and
  license dependencies.
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
2. Is this an app root that only wants runtime/bootstrap mechanics?
   Use `MHAppRuntimeCore`.
3. Is this a shared package or shared library?
   Use `MHPlatformCore` or a concrete module.
4. Is the target only adding route, mutation, or review workflow shells?
   Add those shells explicitly instead of switching umbrellas.
5. Is the target trying to avoid StoreKit, ads, or license dependencies?
   Stay on `MHAppRuntimeCore` until package-owned defaults are needed.

## Evidence Paths

- Full umbrella example app: `Example/MHPlatformExample/`
- Shared-package-safe umbrella tests: `Tests/MHPlatformCoreTests/`
- Full umbrella tests: `Tests/MHPlatformTests/`
- Runtime split composition tests: `Tests/MHAppRuntimeTests/`
