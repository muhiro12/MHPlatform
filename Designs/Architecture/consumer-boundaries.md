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
| Advanced app runtime target | App root that wants runtime, lifecycle, environment injection, and optional route plumbing without the full umbrella | `MHAppRuntime` | `MHAppRuntimeDefaults`, `MHAppRuntimeAds`, `MHAppRuntimeLicenses`, `MHPreferencesUI`, `MHLoggingUI`, `MHMutationFlow`, `MHReviewFlow`, concrete core modules | Pulling `MHPlatform` only to reach bootstrap helpers when the narrower runtime surface is intentional |
| Shared logic package / shared library | `FooLibrary`, watch-capable shared logic package, reusable package target | `MHPlatformCore` or granular core-safe modules | Concrete modules such as `MHDeepLinking`, `MHPreferences`, `MHNotificationPlans`, `MHPersistenceMaintenance` | `MHPlatform`, `MHAppRuntime`, `MHPreferencesUI`, `MHLoggingUI`, `MHReviewPolicy`, `MHReviewRequesting`, `MHReviewFlow` |
| Widget / App Intent / extension adapter | WidgetKit bundles, App Intent adapters, notification/content extensions, Shortcuts adapters | App shared library first, then `MHPlatformCore` or granular core-safe modules for direct platform primitives | `MHDeepLinking`, `MHNotificationPlans`, `MHNotificationPayloads`, `MHPreferences`, `MHRouteExecution` | `MHPlatform`, `MHAppRuntime`, split runtime bundles, ads/license/runtime adapters, UI/review shells |
| Lightweight watch companion surface | Watch app surfaces that mirror shared state or preferences without owning the full app runtime | App shared library, `MHPreferences`, `MHPlatformCore`, or granular core-safe modules | `MHDeepLinking`, `MHNotificationPayloads`, `MHRouteExecution` when the watch surface owns route handoff | Full umbrella adoption unless the watch target intentionally owns an app-root runtime/shell surface |
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
- concrete core modules: `MHDeepLinking`, `MHLogging`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHRouteExecution`, `MHPersistenceMaintenance`,
  `MHPreferences`
- optional UI bridges: `MHPreferencesUI`, `MHLoggingUI`
- opt-in workflow shells: `MHMutationFlow`, `MHMutationLogging`,
  `MHReviewPolicy`, `MHReviewRequesting`, `MHReviewFlow`

Start from a documented public entry point unless the target is intentionally doing
advanced composition around one focused concern.

## Normative Rules

- `MHPlatform` is the full umbrella for app composition targets that
  intentionally want runtime, workflow shells, and the shared core surface from
  one product.
- `MHPlatformCore` is the shared-package umbrella. It is the default umbrella
  for shared packages and shared libraries, and it intentionally excludes
  SwiftUI/UI bridge targets and review workflow shells.
- `MHAppRuntime` is the advanced app-root surface for runtime/bootstrap-only
  apps and explicit split-runtime-bundle composition.
- Widget, App Intent, watch, and extension adapters should call the app's
  shared APIs first. MHPlatform should only appear directly in those surfaces
  when they need reusable platform primitives, and then through
  `MHPlatformCore` or granular core-safe modules.
- `MHPlatform` remains the only one-step default runtime path. Keep the full
  umbrella when the target wants package-owned StoreKit, ads, or license
  integrations without manual composition.
- Split runtime bundles and concrete modules are advanced composition tools,
  not the default onboarding path for new adopters.
- Route, review, and mutation shells are optional. Apps adopt them only when
  that concern exists in the target.
- `MHPreferencesUI` and `MHLoggingUI` are optional UI bridge products. Keep
  them out of shared libraries and non-UI surface adapters unless the target
  is explicitly a UI surface.
- `MHReviewPolicy`, `MHReviewRequesting`, and `MHReviewFlow` are split so pure
  policy, direct platform requesting, and runtime/mutation workflow wiring can
  be adopted independently.
- Shared packages must not depend on `MHPlatform`, `MHAppRuntime`, or
  review/UI shell products. Shared packages should stop at `MHPlatformCore` or
  granular core-safe modules unless a focused standalone product is genuinely
  required.
- Surface adapters must not adopt `MHPlatform` or `MHAppRuntime` just to build
  route URLs, read preferences, plan notifications, resolve notification route
  payloads, or hand off pending routes.

## What Stays App-Owned

- Route enum meaning and navigation destination meaning
- Notification copy and presentation meaning
- Planner business semantics
- Persistence schema meaning and validation
- Preference key meaning and defaults
- SwiftData schema meaning, validation, and model deletion policy
- Domain mutation result and effect meaning
- Other app-specific business semantics
- App-specific `Operations` facades and surface adapter branching

## Consumer Selection Checklist

1. Is this a UI/composition root that wants the full shared platform surface?
   Use `MHPlatform`.
2. Is this an app root that wants runtime/bootstrap mechanics or explicit
   runtime composition without the full umbrella?
   Use `MHAppRuntime`.
3. Is this a shared package or shared library?
   Use `MHPlatformCore` or a concrete module.
4. Is this a widget, App Intent, watch, or extension adapter?
   Call the app shared library first; use `MHPlatformCore` or granular
   core-safe modules only for direct platform primitives.
5. Is the target only adding route, mutation, or review workflow shells?
   Add those shells explicitly instead of switching umbrellas.
6. Does the app want package-owned StoreKit, ads, or license integrations
   without the full umbrella?
   Add the split runtime bundles explicitly on top of `MHAppRuntime`.
7. Does the target only need SwiftUI preference bindings or a log console?
   Add `MHPreferencesUI` or `MHLoggingUI` explicitly.

## Evidence Paths

- Full umbrella example app: `Example/MHPlatformExample/`
- Shared-library consumer fixture: `Fixtures/Consumers/SharedLibraryConsumer/`
- Runtime-only consumer fixture: `Fixtures/Consumers/RuntimeOnlyConsumer/`
- Explicit split-runtime consumer fixture:
  `Fixtures/Consumers/SplitRuntimeConsumer/`
- Optional-shell consumer fixture: `Fixtures/Consumers/OptionalShellConsumer/`
- Surface-adapter consumer fixture:
  `Fixtures/Consumers/SurfaceAdapterConsumer/`
- Shared-package-safe umbrella tests: `Tests/MHPlatformCoreTests/`
- Full umbrella tests: `Tests/MHPlatformTests/`
- Optional UI bridge tests: `Tests/MHPreferencesUITests/`,
  `Tests/MHLoggingUITests/`
- Review shell tests: `Tests/MHReviewPolicyTests/`,
  `Tests/MHReviewRequestingTests/`, `Tests/MHReviewFlowTests/`
- Runtime split composition tests: `Tests/MHAppRuntimeTests/`
- CI consumer fixture build task: `ci_scripts/tasks/test_consumer_fixtures.sh`
