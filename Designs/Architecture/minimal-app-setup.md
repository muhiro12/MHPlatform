# MHPlatform Minimal App Setup

Use this as the default starting point for a brand-new app.

`MHPlatform` is the default app-facing package for new apps. Import
`MHAppRuntime` directly only when the app intentionally wants the narrower
runtime/bootstrap foundation or explicit split-runtime-bundle composition.

## Root Ownership

Own one app-side assembly object that keeps:

- the app's navigation model
- the app's service graph
- one `MHAppRuntimeBootstrap`

Keep `MHAppRuntimeBootstrap` at the root boundary. Apply it once from the app's
root view with `View.mhAppRuntimeBootstrap(_:)`.

## Runtime-only Path

If the app does not use route, mutation, or review shells, stop here:

- import `MHAppRuntime`
- create one `MHAppRuntimeBootstrap`
- use `.mhAppRuntimeBootstrap(...)` for a real app root
- use `.mhAppRuntimeEnvironment(...)` for preview/test runtime injection only

Keep preview/test-only model containers and service doubles in the app factory.
MHPlatform intentionally does not own that assembly.

If the app wants package-owned StoreKit, ads, or license integrations without
the full `MHPlatform` umbrella, compose `MHAppRuntime` manually with
`MHAppRuntimeDefaultsBundle`, `MHAppRuntimeAdsBundle`, and
`MHAppRuntimeLicensesBundle`.

## Route-enabled Path

Keep route meaning in the app.

- use `MHAppRoutePipeline` for URL ingestion, source ordering, readiness, and
  drain orchestration
- use `MHObservableRouteInbox<Route>` when the UI wants replace-latest route
  handoff before mutating navigation state
- use `View.mhRouteHandler(_:apply:)` to register the app-owned route apply
  closure while keeping replay and temporary buffering package-owned
- apply routes directly inside the pipeline only when no intermediate route
  inbox is needed

Recommended shape:

```swift
@MainActor
final class AppAssembly {
    let navigationModel = NavigationModel()
    let routeInbox = MHObservableRouteInbox<AppRoute>()
    let bootstrap: MHAppRuntimeBootstrap

    init(logger: MHLogger) {
        let routePipeline = MHAppRoutePipeline(
            routeLifecycle: .init(
                logger: logger,
                initialReadiness: false,
                isDuplicate: ==
            ),
            using: codec,
            routeInbox: routeInbox,
            pendingSources: [intentStore, notificationInbox]
        )

        bootstrap = .init(
            runtimeOnlyConfiguration: runtimeConfiguration,
            lifecyclePlan: .init(
                activeTasks: [
                    routePipeline.task(name: "synchronizePendingRoutes")
                ]
            ),
            routePipeline: routePipeline
        )
    }
}
```

`MHAppRoutePipeline` logs activation and route-apply failures by default.
Attach `onFailure:` only when the app needs additional telemetry, alerting, or
custom recovery behavior.

## Mutation And Review

- use `MHMutationWorkflow.runThrowing(..., adapterValue:)` when the operation
  value should be returned unchanged and only the adapter input is fixed
- use `projection:` when adapter input and return value need different shaping
- attach `MHReviewFlow.step(name:)` to successful mutation follow-up
- attach `MHReviewFlow.task(name:)` only to lifecycle or activation prompts

## Preview Setup

Keep preview assembly shape close to production:

- return the same app assembly type from live and preview factories
- use preview-safe services or an empty `MHAppRuntimeLifecyclePlan`
- omit route handoff sources only when the preview does not exercise them
- do not invent preview-only route semantics inside MHPlatform
- when composing `MHAppRuntime` manually, use `MHRuntimeViewFactory` and
  `MHRuntimeNativeAdViewFactory` instead of raw `AnyView` builders
- keep model container ownership and other app-specific test fixtures in the
  app factory
- use `View.mhAppRuntimeEnvironment(_:)` when the preview only needs runtime
  environment without lifecycle start

## One SwiftData store for the app family

Start with the [buildable assembly](../../Fixtures/Consumers/SharedLibraryConsumer/Sources/SharedLibraryConsumer/SharedStoreAssembly.swift)
and its [disk tests](../../Fixtures/Consumers/SharedLibraryConsumer/Tests/SharedLibraryConsumerTests/SharedStoreTests.swift).
Declare the schema, optional migration plan, relative store location, App Group,
and private CloudKit container once in the shared app library. Each process
creates its own context. Only the host creates directories, migrates, and
enables cloud mirroring. The extension opens the existing store read-only;
if the store is missing or needs migration, ask the user to open the host.
Propagate errors instead of trying a different database. Previews and tests
explicitly select an isolated memory store. Existing apps retain their own
store paths, migration plans, cloud subscriptions, and account policies.

Both signed targets need the same App Group entitlement and provisioning.
The syncing host also needs iCloud with CloudKit and the configured container,
push notifications, and background remote notifications. Verify the signed
entitlements and production schema in the intended deployment environment.
On devices, check extension-first launch, account sign-out/change with edits
pending, and create/edit/delete convergence on two devices. The local disk
tests exercise store ownership; they do not establish any of those cloud results.

For ordinary DEBUG runs, use the [isolated development-store recipe](development-store.md)
to keep editable sample data across launches without opening the user store.
It also covers manual sample insertion and the boundary between distributed
diagnostics and development-only controls.
