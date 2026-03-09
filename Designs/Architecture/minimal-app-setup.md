# MHPlatform Minimal App Setup

Use this as the default starting point for a brand-new app.

## Root Ownership

Own one app-side assembly object that keeps:

- the app's navigation model
- the app's service graph
- one `MHAppRuntimeBootstrap`

Keep `MHAppRuntimeBootstrap` at the root boundary. Apply it once from the app's
root view with `View.mhAppRuntimeBootstrap(_:)`.

## Route Handoff

Keep route meaning in the app.

- use `MHAppRoutePipeline` for URL ingestion, source ordering, readiness, and
  drain orchestration
- use `MHObservableRouteInbox<Route>` when the UI wants replace-latest route
  handoff before mutating navigation state
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
            configuration: runtimeConfiguration,
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
