# MHPlatform Status

## This Phase

- Added identity-route helpers in `MHRouteExecution` so `Route == Outcome`
  flows can keep app-owned apply logic without dummy resolve/apply closures.
- Added codec-backed route helpers in `MHDeepLinking` so inbox/store handoff
  can ingest and consume app-owned routes while still storing `URL` values.
- Refreshed the route pipeline demo and docs so `MHRouteLifecycle` is the
  current helper-first adoption path, while `MHRouteCoordinator` remains the
  low-level execution surface.
- Added `MHLoggerFactory` in `MHLogging` as a thin helper for app-owned logger
  setup around `MHLogStore`, `MHLogPolicy`, and optional subsystem/category
  defaults.
- Added `MHMutationAdapter.appending(_:)` so apps can combine fixed and
  value-derived follow-up steps without introducing a shared mutation schema.
- Added `MHMutationWorkflow` and `MHMutationWorkflowError` so apps can stop
  recreating the same thin failure-mapping shell around `MHMutationRunner`.
- Updated `MHPlatformExample` to demonstrate these helpers through the umbrella
  `MHPlatform` product.
- Refreshed the README and architecture docs to describe these helper
  boundaries as additive app-facing ergonomics rather than platform-owned
  workflow policy.
- Audited the touched public API surface and did not find additional naming or
  access-control cleanup worth a separate change.

## Implemented in MHPlatform

- Umbrella product `MHPlatform` plus modular products for runtime, deep links,
  notification planning/payloads, mutation flow, route execution, persistence
  maintenance, preferences, review policy, and logging.
- `MHAppRuntime` as the shared runtime/startup surface already used by app
  targets.
- `MHReviewPolicy` as the shared review-request policy surface.
- `MHDeepLinking` with URL grammar primitives plus codec-backed inbox/store
  helpers for app-owned route handoff.
- `MHRouteExecution` with readiness-aware execution, `MHRouteLifecycle`, and
  an identity-route path for `Route == Outcome` flows.
- `MHLogging` with structured logging, query/export surfaces, and
  `MHLoggerFactory` for shared setup ergonomics.
- `MHMutationFlow` with retry, cancellation, fixed `afterSuccess` steps, and
  value-driven `MHMutationAdapter`, additive adapter composition, and the
  higher-level `MHMutationWorkflow` shell.

## Adopted in Apps Today

- Incomes imports `MHPlatform` in app bootstrap, root views, ads/store/license
  surfaces, debug sample data, and review-trigger call sites.
- Cookle imports `MHPlatform` in app bootstrap, root views, ads/store/license
  surfaces, debug sample data, and review-trigger call sites.
- Both apps currently use `MHAppRuntime` and `MHReviewPolicy`.
- Both apps already use `MHRouteLifecycle` as the route-execution shell while
  keeping route parsing and route application logic app-owned.
- Deep-link handoff helpers are partially adopted today:
  Incomes uses `MHDeepLinkInbox`, while Cookle already uses
  `MHObservableDeepLinkInbox` in its app graph.
- Both apps now keep local mutation workflow wrappers whose shape matches
  `MHMutationWorkflow`, but direct package-side adoption remains deferred.

Reference evidence:
- `Incomes/Incomes/Sources/IncomesApp.swift`
- `Incomes/Incomes/Sources/ContentView.swift`
- `Incomes/Incomes/Sources/Main/Views/MainNavigationRouter.swift`
- `Incomes/Incomes/Sources/Notification/Models/NotificationService.swift`
- `Incomes/Incomes/Sources/Common/Services/IncomesMutationWorkflow.swift`
- `Cookle/Cookle/CookleApp.swift`
- `Cookle/Cookle/ContentView.swift`
- `Cookle/Cookle/Sources/Main/Services/MainRouteService.swift`
- `Cookle/Cookle/Sources/Main/Views/MainView.swift`
- `Cookle/Cookle/Sources/Common/Services/CookleMutationWorkflow.swift`

## Still App-Specific

- Mutation result models and follow-up metadata remain app-owned.
  - Incomes keeps `followUpHints` in `Incomes/IncomesLibrary/Sources/Common/MutationOutcome.swift`.
  - Cookle keeps `MutationOutcome` / `MutationEffect` in `Cookle/CookleLibrary/Sources/Common/`.
- Concrete platform side effects remain app-owned:
  notification refresh, widget reload, watch sync, review trigger timing, and
  other workflow-local behavior.
- Route enums, navigation state, and the exact `apply` closures passed to
  `MHRouteExecution` remain app-owned.
- Logging categories, subsystem naming, and sink selection remain app-owned
  even when the app uses `MHLoggerFactory`.
- App navigation state, persistence model rules, and target-local workflow
  services remain outside MHPlatform.

## Next Likely Step

- Pick one narrow save/update workflow in either app.
- Prefer a workflow that also touches route handoff or logging so one pilot can
  exercise multiple new helper surfaces together.
- Keep the app's current mutation result model.
- Add an app-local bridge from that result model into `MHMutationAdapter`.
- Adopt `MHMutationFlow` only for retry, cancellation, event streaming, and
  ordered post-success sequencing in that workflow.
