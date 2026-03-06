# MHPlatform Status

## This Phase

- Added `MHMutationAdapter<Value>` in `Sources/MHMutationFlow/` so apps can
  derive ordered `MHMutationStep`s from app-owned success values.
- Added adapter-focused coverage for Incomes-like `followUpHints`,
  Cookle-like `effects`, retry, step failure, and cancellation behavior.
- Refreshed the README and architecture docs to describe the current umbrella +
  modular adoption model and the `MHMutationFlow` adapter boundary.
- Updated `MHPlatformExample` to depend on the umbrella `MHPlatform` product
  and to demonstrate adapter-driven mutation follow-ups.
- Audited the touched public API surface and did not find additional naming or
  access-control cleanup worth a separate change.

## Implemented in MHPlatform

- Umbrella product `MHPlatform` plus modular products for runtime, deep links,
  notification planning/payloads, mutation flow, route execution, persistence
  maintenance, preferences, review policy, and logging.
- `MHAppRuntime` as the shared runtime/startup surface already used by app
  targets.
- `MHReviewPolicy` as the shared review-request policy surface.
- `MHMutationFlow` with retry, cancellation, fixed `afterSuccess` steps, and
  value-driven `MHMutationAdapter`.

## Adopted in Apps Today

- Incomes imports `MHPlatform` in app bootstrap, root views, ads/store/license
  surfaces, debug sample data, and review-trigger call sites.
- Cookle imports `MHPlatform` in app bootstrap, root views, ads/store/license
  surfaces, debug sample data, and review-trigger call sites.
- Both apps currently use `MHAppRuntime` and `MHReviewPolicy`.
- Neither app imports `MHMutationFlow` yet.

Reference evidence:
- `Incomes/Incomes/Sources/IncomesApp.swift`
- `Incomes/Incomes/Sources/ContentView.swift`
- `Cookle/Cookle/CookleApp.swift`
- `Cookle/Cookle/ContentView.swift`

## Still App-Specific

- Mutation result models and follow-up metadata remain app-owned.
  - Incomes keeps `followUpHints` in `Incomes/IncomesLibrary/Sources/Common/MutationOutcome.swift`.
  - Cookle keeps `MutationOutcome` / `MutationEffect` in `Cookle/CookleLibrary/Sources/Common/`.
- Concrete platform side effects remain app-owned:
  notification refresh, widget reload, watch sync, review trigger timing, and
  other workflow-local behavior.
- App navigation state, persistence model rules, and target-local workflow
  services remain outside MHPlatform.

## Next Likely Step

- Pick one narrow save/update workflow in either app.
- Keep the app's current mutation result model.
- Add an app-local bridge from that result model into `MHMutationAdapter`.
- Adopt `MHMutationFlow` only for retry, cancellation, event streaming, and
  ordered post-success sequencing in that workflow.
