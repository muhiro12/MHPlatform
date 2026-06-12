# MHPlatform

MHPlatform is an internal Apple-platform foundation delivered as a Swift
package workspace. It centralizes reusable, app-agnostic infrastructure proven
through Incomes and Cookle while keeping app-specific domain behavior in the
adopting apps.

The package ships three main adoption pillars:

- `MHPlatform`: full app-facing convenience umbrella.
- `MHPlatformCore`: shared-library-safe umbrella for core primitives.
- `MHAppRuntime`: advanced app-root runtime/bootstrap surface for explicit
  composition.

The current 1.x beta baseline focuses on runtime startup, deep-link handoff,
route execution, deterministic notification planning, notification payload
routing, post-mutation side-effect orchestration, logging, preferences,
persistence maintenance, review policy, and small non-UI Foundation/SwiftData
utilities.

Minimum supported platforms:

- iOS 18.0+
- macOS 15.0+
- watchOS 11.0+

## Versioning Posture

- `1.x` is treated as beta. Public APIs may change while the shared surface is
  still being shaped.
- MHPlatform does not keep app-upgrade fallback paths, compatibility aliases,
  or historical shell support solely to ease SDK updates during `1.x`.
- Caller-owned relocation or migration primitives remain in scope when they
  operate on the app's current configuration and schema policy stays in the
  app.
- Adopters should follow the current documentation and current public surface
  on each update.

## Documentation Map

Read these first when choosing products or integrating a consumer:

- [Consumer Boundaries](Designs/Architecture/consumer-boundaries.md):
  normative 1.x consumer matrix.
- [Consumer Adoption](Designs/Architecture/adoption-policy.md):
  product-selection rationale and current shell preferences.
- [Minimal App Setup](Designs/Architecture/minimal-app-setup.md): compact app
  bootstrap path.
- [Integration Contracts](Designs/Architecture/integration-contracts.md):
  module-by-module public contracts.

Use these when changing architecture or reviewing durable decisions:

- [Architecture Guide](Designs/Architecture/ARCHITECTURE_GUIDE.md):
  `platform-in-package, app-as-adapter` policy.
- [Architecture](Designs/Architecture/architecture.md): module and dependency
  boundaries.
- [Integration Cookbook](Designs/Architecture/integration-cookbook.md):
  detailed integration examples.
- [Runtime-start Design](Designs/Architecture/runtime-start.md): runtime
  bootstrap design.
- [North Star](Designs/Architecture/north-star.md): long-term extraction
  direction.
- [Design Decisions](Designs/Decisions/README.md): ADR index.
- [Platform Status](Designs/Overviews/platform-status.md): current adoption
  status.
- [Verification History](Designs/Overviews/verification-history.md): durable
  verification contract and run artifact layout.
- [Backlog](Designs/Overviews/backlog.md): extraction history and current
  backlog posture.

This README is intentionally an adoption map. Keep detailed API walkthroughs in
the architecture documents above so the entry point stays readable.

## Directory Conventions

- Keep the top-level package layout stable: `Sources/`, `Tests/`, `Fixtures/`,
  `Example/`, `Designs/`, and `ci_scripts/`.
- Organize `Sources/<Target>/` with shallow responsibility-based folders such
  as `Configuration`, `Runtime`, `Routing`, `Workflow`, `Store`, and `SwiftUI`.
- Keep small targets flat when subdirectories do not improve discoverability.
- Put test-only helpers under `Tests/<Target>/Support/`.
- Use `Fixtures/Consumers/` for compile-backed adoption references by consumer
  type.
- Keep the example app shell in `Example/MHPlatformExample/App/` and place
  module demos under `Example/MHPlatformExample/Demos/<Area>/`.

## Product Selection

Use [Consumer Boundaries](Designs/Architecture/consumer-boundaries.md) as the
source of truth before adding package dependencies.

- Full-platform app targets should use `MHPlatform` when they intentionally
  want the default runtime, core primitives, mutation shell, and review shell
  from one import.
- Advanced app-runtime targets should use `MHAppRuntime` when they want
  runtime/bootstrap mechanics without the full umbrella.
- Shared logic packages and shared libraries should use `MHPlatformCore` or
  granular core-safe modules.
- Widget, App Intent, watch, and extension adapters should call app-owned
  shared APIs first. If they need direct MHPlatform primitives, use
  `MHPlatformCore` or granular core-safe modules.
- Optional route, mutation, and review shells should be added only to targets
  that own those concerns.

Avoid `MHPlatform`, `MHAppRuntime`, split runtime bundles, ads, license, and
review dependencies in surface adapters unless the target intentionally owns an
app-root runtime surface.

## Public Products

Default adoption pillars:

- `MHPlatform`
- `MHPlatformCore`

Advanced app-root surface:

- `MHAppRuntime`

Advanced runtime composition bundles:

- `MHAppRuntimeDefaults`
- `MHAppRuntimeAds`
- `MHAppRuntimeLicenses`

Granular core-safe products and optional shells:

- `MHDeepLinking`
- `MHLogging`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHPlatformUtilities`
- `MHMutationFlow`
- `MHMutationLogging`
- `MHReviewPolicy`

Test support:

- `MHPlatformTesting`

## Boundary Rules

- `MHPlatform` remains a thin convenience umbrella over concrete modules.
- `MHPlatformCore` must not pull in `MHAppRuntime`, app-root runtime adapters,
  StoreKit, ads, licenses, mutation workflow, or review policy.
- `MHAppRuntime` owns reusable runtime/bootstrap mechanics, not StoreKit, ads,
  license, or app-specific side-effect policy.
- Route enum meaning, navigation destination meaning, notification copy,
  preference key meaning, persistence schema meaning, mutation result schemas,
  and concrete side effects stay app-owned.
- App-specific `*Operations` facades belong in adopting app shared libraries,
  not in MHPlatform.
- `MHPlatformTesting` is a separate test-support product and must not be
  re-exported by production umbrellas.

Direct third-party dependency rule:

- `MHPlatform` does not re-export third-party symbols from `StoreKitWrapper`,
  `GoogleMobileAdsWrapper`, or `LicenseList`.
- If consumer code uses those APIs directly, add the third-party package as a
  direct dependency and `import` that module explicitly.

## Fixture-Backed Evidence

Compile-backed reference adopters live under `Fixtures/Consumers/`.

- `SharedLibraryConsumer` proves the `MHPlatformCore` shared-library path.
- `RuntimeOnlyConsumer` proves the `MHAppRuntime` runtime/bootstrap-only path.
- `SplitRuntimeConsumer` proves explicit runtime-bundle composition.
- `OptionalShellConsumer` proves route/review/mutation shells stay opt-in.
- `SurfaceAdapterConsumer` proves the widget, App Intent, watch, and extension
  adapter path using only granular core-safe products.

Package tests and integration tests cover the module behavior behind those
consumer paths. `Example/MHPlatformExample/` remains the full-umbrella demo app.

## Current Adoption Snapshot

- Incomes and Cookle currently adopt MHPlatform primarily through the umbrella
  `MHPlatform` product in app composition targets.
- `MHAppRuntime` is the shared runtime/startup surface used by app targets.
- `MHRouteExecution`, `MHDeepLinking`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHPreferences`, `MHLogging`, `MHMutationFlow`, and
  `MHReviewPolicy` provide reusable infrastructure while route meanings,
  mutation effects, notification copy, review timing, and platform side effects
  stay app-owned.
- Shared-library and surface-adapter consumers should follow the consumer
  matrix instead of mirroring an app target's umbrella imports.

## Example App

`MHPlatformExample` demonstrates the full `MHPlatform` umbrella with app-local
sample data in `Example/`.

It includes cross-module demos for:

- Deep-link inbox and route-lifecycle pipelines.
- Low-level route execution.
- Notification planning and notification payload routing.
- Mutation workflow and review policy integration.
- Structured logging and last-session diagnostics.
- Mutation adapter composition with ordered follow-up steps.

Consumer-specific minimal adopters live in `Fixtures/Consumers/` instead of
duplicating narrower paths inside the demo app.

## Requirements

- Xcode 16 or later with the iOS 18, macOS 15, and watchOS 11 SDKs installed.
- `swiftlint` for repository verification and strict lint runs.

## Setup

1. Clone the repository and open the project directory.
2. Open `Package.swift` in Xcode if you want package browsing and test support.
3. Open `Example/MHPlatformExample.xcodeproj` if you want to run the demo app
   shell.
4. Use the helper scripts in `ci_scripts/tasks/` for repeatable local
   verification.

## Build and Test

For full local verification:

```sh
bash ci_scripts/tasks/verify_task_completion.sh
```

Use `verify_repository_state.sh` when you only want required checks based on
local package changes:

```sh
bash ci_scripts/tasks/verify_repository_state.sh
```

If you only need the package and example app build:

```sh
bash ci_scripts/tasks/build_app.sh
```

If you only need Swift package tests:

```sh
bash ci_scripts/tasks/test_shared_library.sh
```

If you want an optional local push hook:

```sh
bash ci_scripts/tasks/verify_pre_push.sh
```

`ci_scripts/tasks/verify.sh` remains only as a legacy compatibility wrapper
around `verify_task_completion.sh`.

The retained shell gate covers SwiftLint, SwiftPM tests, consumer fixture
builds, example-project builds, repository-specific static rules, and generated
run artifacts. Use XcodeBuildMCP or official Apple tooling when a change needs
live Apple runtime, Simulator, screenshot, UI snapshot, or Xcode-specific
evidence.

## CI Artifact Layout

CI helper scripts write generated artifacts under `.build/ci/`.
Run-scoped outputs are stored in `.build/ci/runs/<RUN_ID>/` (`summary.md`,
`commands.txt`, `meta.json`, `logs/`, `results/`, `work/`), while shared
caches and build state live in `.build/ci/shared/` (`cache/`, `DerivedData/`,
`tmp/`, `home/`).
