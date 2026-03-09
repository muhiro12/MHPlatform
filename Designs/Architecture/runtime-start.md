# MHAppRuntime Runtime-start Design

## Why `startIfNeeded` exists

`MHAppRuntime` provides a single startup entry point for shared app platform side
effects. `MHAppRuntimeBootstrap` is the package-owned assembly shell that now
binds runtime startup, lifecycle coordination, optional route plumbing, and
SwiftUI environment injection into one root integration surface.

`startIfNeeded()` is idempotent. Repeated calls are safe and do not repeat
startup side effects.

## Bootstrap shell

`MHAppRuntimeBootstrap` owns the package side of runtime assembly:

- `MHAppRuntime`
- `MHAppRuntimeLifecyclePlan`
- `MHAppRuntimeLifecycle` creation through `makeLifecycle()`
- optional route inbox exposure for app-owned services
- SwiftUI root integration through `View.mhAppRuntimeBootstrap(_:)`

For a brand-new app starting point, pair this design note with
[`minimal-app-setup.md`](minimal-app-setup.md). For older app-side glue, use
[`migrating-to-current-shells.md`](migrating-to-current-shells.md).

Runtime-only apps can import `MHAppRuntimeCore` instead of the full
`MHAppRuntime` product when they do not use StoreKit, ads, or runtime-owned
license views.

This moves the repeated "runtime + lifecycle + route root wiring + environment"
shape out of app roots and into MHPlatform while leaving app-specific services,
model containers, and route meanings outside the package.

## Lifecycle shell

`MHAppRuntimeLifecycle` owns three pieces of repeated app wiring:

- calling `runtime.startIfNeeded()` from initial appearance and active-phase hooks
- running ordered `startupTasks` once
- running ordered `activeTasks` whenever the app becomes active, with optional
  `skipFirstActivePhase` behavior for apps that already performed equivalent
  work during startup

This keeps app-specific work items explicit while moving the lifecycle
coordination mechanics into MHPlatform.

`MHAppRuntimeLifecyclePlan` also supports `commonTasks` so apps can define
shared startup/active work once while preserving explicit per-phase tasks.

For SwiftUI entry points, `View.mhAppRuntimeBootstrap(_:)` is now the preferred
adapter and `View.mhAppRuntimeLifecycle(runtime:plan:)` remains the lower-level
escape hatch. Both keep `scenePhase` observation and lifecycle object storage
inside MHPlatform while preserving the same ordered task plan.

For previews and tests that should not start lifecycle tasks, use
`View.mhAppRuntimeEnvironment(_:)`.
MHPlatform intentionally leaves preview/test model container ownership and
other app-specific fixtures outside this surface.

## Route pipeline shell

`MHAppRoutePipeline` owns repeated root-level route plumbing that sat next to
runtime lifecycle wiring in app code:

- a pipeline-owned `MHObservableDeepLinkInbox`
- ordered pending-source composition with the pipeline inbox appended last
- one-time route execution activation through `MHRouteLifecycle`
- one-at-a-time pending URL drain
- optional handoff into `MHObservableRouteInbox<Route>` before app-owned
  navigation mutation
- lifecycle task generation through `task(name:)`
- SwiftUI `onOpenURL` and `NSUserActivityTypeBrowsingWeb` ingestion through
  `View.mhAppRoutePipeline(_:)` or `View.mhAppRuntimeBootstrap(_:)`

Apps still own route enums, parsing meaning, and final route application.

## What runtime initializes

`MHAppRuntime` currently initializes:

- StoreKit subscription monitoring and paywall section wiring
- Google Mobile Ads startup (when ad unit is configured)
- Premium status projection used for ad availability gating
- Typed preference store backed by configured `UserDefaults` suite
- License view exposure (when enabled)

## Dependency decisions

`MHAppRuntime` uses:

- `StoreKitWrapper`:
  kept because it provides transaction monitoring and paywall UI composition.
- `GoogleMobileAdsWrapper`:
  kept because it provides native-ad loading and SwiftUI/UIKit bridge surfaces.
- `LicenseList` (direct):
  adopted directly because the previous wrapper layer was only a thin forwarding
  view with no meaningful boundary value.
- `SwiftUtilities`:
  intentionally not used for runtime v1 to keep the dependency surface minimal.

## Non-goals

`MHAppRuntime` does not own:

- app domain rules
- app-specific navigation state
- SwiftData schema ownership or migration policy
- remote configuration policy
- SDK-specific types in app-facing configuration APIs
- the meaning of startup or active tasks beyond their execution order
