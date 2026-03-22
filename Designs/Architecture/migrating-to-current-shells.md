# Migrating To Current Consumer Surfaces

Use this page when older app glue or outdated package adoption still exists
around runtime, route, review, mutation, or product selection.

## Consumer Product Migration

| Old shape | Current surface | Notes |
|---|---|---|
| shared library target depends on `MHPlatform` but only imports core-safe APIs | `MHPlatformCore` | keep route meaning, preference meaning, and notification semantics in the adopter |
| runtime/bootstrap-only app depends on `MHPlatform` or `MHAppRuntime` only for bootstrap, lifecycle, environment, and optional route plumbing | `MHAppRuntimeCore` | add split runtime bundles later only if package-owned StoreKit, ads, or license integrations become necessary |
| target adds route, mutation, or review concerns by switching umbrellas | keep the existing base product and add only the required shell | route, mutation, and review shells are optional |
| app repository pins MHPlatform with `branch: "main"` | exact tag, exact version, or coordinated exact revision | see `adoption-policy.md` for the supported 1.0 posture |

## Old Glue -> Current Surface

| Old shape | Current surface | Notes |
|---|---|---|
| root-owned `MHAppRuntime` + manual `.environment(runtime)` + `mhAppRuntimeLifecycle(runtime:plan:)` | `MHAppRuntimeBootstrap` + `mhAppRuntimeBootstrap(_:)` | preferred root entry for new apps |
| manual `onOpenURL` / `NSUserActivity` / `activate` / `submitLatest` wiring | `MHAppRoutePipeline` + `routePipeline.task(name:)` | keeps route drain placement explicit in the lifecycle plan |
| thin app-owned replace-latest route inbox | `MHObservableRouteInbox<Route>` | keep route meaning in app; move only route handoff mechanics into MHPlatform |
| manual handler registration / unregister / replay around route inbox | `mhRouteHandler(_:_:)` | package-owned handler lifecycle for replace-latest route handoff |
| `MHReviewPolicy` + `MHReviewRequester` + custom logger/source/task/step glue | `MHReviewFlow` | use `task(name:)` and `step(name:)` instead of rewiring triggers |
| wrappers around `.fixedAdapterValue(...)` for `Void` or identifier mutations | `MHMutationWorkflow.runThrowing(..., adapterValue:)` | keep `projection:` for non-trivial shaping |
| manual conditional `[MHMutationStep]` array mutation from app-owned effect flags | `MHMutationAdapter.build { ... }` | use `if` / `for` with `MHMutationStepListBuilder` instead of a second builder API |
| manual `.environment(bootstrap.runtime)` in previews or tests | `mhAppRuntimeEnvironment(_:)` | inject runtime without starting lifecycle tasks |

## Migration Notes

- select the base product first, then add optional shells only where the
  target owns that concern
- shared libraries should migrate from `MHPlatform` to `MHPlatformCore` when
  they only need core-safe APIs
- runtime/bootstrap-only apps should migrate from `MHPlatform` or
  `MHAppRuntime` to `MHAppRuntimeCore` when they do not need package-owned
  StoreKit, ads, or license integrations
- released app repositories should stop using `branch: "main"` and move to
  exact tag or exact version adoption
- coordinated pre-release validation may use an exact revision, but that is
  still a controlled pin rather than rolling branch adoption
- pin edits in downstream app repositories are outside the scope of this run
- keep low-level primitives when the app genuinely needs custom composition
- do not move route enums, navigation destinations, or domain effect meaning
  into MHPlatform
- prefer `MHAppRuntimeBootstrap` as the starting point, then drop to
  `mhAppRuntimeLifecycle` or `mhAppRoutePipeline` only for custom root wiring
- keep review eligibility decisions in the app even when the triggering shell
  moves to `MHReviewFlow`
- keep preview/test model containers in the app factory; MHPlatform only owns
  runtime/bootstrap mechanics
