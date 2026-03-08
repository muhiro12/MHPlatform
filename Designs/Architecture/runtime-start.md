# MHAppRuntime Runtime-start Design

## Why `startIfNeeded` exists

`MHAppRuntime` provides a single startup entry point for shared app platform side
effects. `MHAppRuntimeLifecycle` layers ordered startup and foreground tasks on
top so apps can stop repeating view-local lifecycle coordination.

`startIfNeeded()` is idempotent. Repeated calls are safe and do not repeat
startup side effects.

## Lifecycle shell

`MHAppRuntimeLifecycle` owns three pieces of repeated app wiring:

- calling `runtime.startIfNeeded()` from initial appearance and active-phase hooks
- running ordered `startupTasks` once
- running ordered `activeTasks` whenever the app becomes active, with optional
  `skipFirstActivePhase` behavior for apps that already performed equivalent
  work during startup

This keeps app-specific work items explicit while moving the lifecycle
coordination mechanics into MHPlatform.

For SwiftUI entry points, `View.mhAppRuntimeLifecycle(runtime:plan:)` is the
default adapter. It keeps `scenePhase` observation and lifecycle object storage
inside MHPlatform while preserving the same ordered task plan.

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
