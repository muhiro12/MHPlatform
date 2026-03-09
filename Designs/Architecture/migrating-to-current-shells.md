# Migrating To Current Shells

Use this page when older app glue still exists around runtime, route, review,
or mutation setup.

## Old Glue -> Current Surface

| Old shape | Current surface | Notes |
|---|---|---|
| root-owned `MHAppRuntime` + manual `.environment(runtime)` + `mhAppRuntimeLifecycle(runtime:plan:)` | `MHAppRuntimeBootstrap` + `mhAppRuntimeBootstrap(_:)` | preferred root entry for new apps |
| manual `onOpenURL` / `NSUserActivity` / `activate` / `submitLatest` wiring | `MHAppRoutePipeline` + `routePipeline.task(name:)` | keeps route drain placement explicit in the lifecycle plan |
| thin app-owned replace-latest route inbox | `MHObservableRouteInbox<Route>` | keep route meaning in app; move only route handoff mechanics into MHPlatform |
| `MHReviewPolicy` + `MHReviewRequester` + custom logger/source/task/step glue | `MHReviewFlow` | use `task(name:)` and `step(name:)` instead of rewiring triggers |
| wrappers around `.fixedAdapterValue(...)` for `Void` or identifier mutations | `MHMutationWorkflow.runThrowing(..., adapterValue:)` | keep `projection:` for non-trivial shaping |
| manual `.environment(bootstrap.runtime)` in previews or tests | `mhAppRuntimeEnvironment(_:)` | inject runtime without starting lifecycle tasks |

## Migration Notes

- keep low-level primitives when the app genuinely needs custom composition
- do not move route enums, navigation destinations, or domain effect meaning
  into MHPlatform
- prefer `MHAppRuntimeBootstrap` as the starting point, then drop to
  `mhAppRuntimeLifecycle` or `mhAppRoutePipeline` only for custom root wiring
- keep review eligibility decisions in the app even when the triggering shell
  moves to `MHReviewFlow`
