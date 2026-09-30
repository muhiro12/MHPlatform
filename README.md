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

The current baseline focuses on runtime startup, deep-link handoff,
route execution, deterministic notification planning, notification payload
routing, post-mutation side-effect orchestration, logging, preferences,
persistence maintenance, review policy, and opt-in UI/workflow shells.

Minimum supported platforms:

- iOS 18.0+
- macOS 15.0+
- watchOS 11.0+

## Versioning Posture

Releases use `MAJOR.MINOR.PATCH`. Pushes to `main` automatically publish the
next minor version with the patch reset to zero. A manual release can select an
explicit major or patch version. Legacy `MAJOR.MINOR` tags are treated as
`MAJOR.MINOR.0`; rerunning an already tagged commit does not create another release.

From this transition onward, incompatible public API changes require a major
version, compatible features a minor version, and fixes a patch version.
Version 1.14.0 is an explicit transition exception: it replaces the beta native
ad size API while retaining the requested minor version increment.

### Migrating Native Ads to 1.14.0

Replace `MHNativeAdSize.small` / `.medium` with
`MHNativeAdLayout.compact` / `.media`, and change the argument label:

```swift
// Before
runtime.nativeAdView(size: .small)
runtime.nativeAdView(size: .medium)

// After
runtime.nativeAdView(layout: .compact)
runtime.nativeAdView(layout: .media)
```

Custom `MHRuntimeNativeAdViewFactory` closures now receive `MHNativeAdLayout`;
its `makeView(size:)` method becomes `makeView(layout:)`. The factory callback
and `makeView(layout:)` run on `MainActor`, matching SwiftUI view creation.
The removed types and labels have no compatibility aliases.
If an app persists the old enum raw values, migrate `"small"` to `"compact"`
and `"medium"` to `"media"` before decoding the new enum. MHPlatform does not
automatically rewrite app-owned preferences.
Ads use the available width and their natural height. Apply app-owned padding,
background, and optional `.frame` constraints at the call site; recheck any
fixed heights previously chosen for Small or Medium.

GoogleMobileAdsWrapper 2.0.0 and Google Mobile Ads 13.10.0 provide the new
code-built native ad views. SDK initialization completes before the adapter
creates an ad request. 1.14.0 itself adds no consent orchestration; see
[Consent-managed Ads](#consent-managed-ads) for the opt-in lifecycle.

## Consent-managed Ads

Set `adsConsent` to let the runtime run Google's User Messaging Platform before
it starts advertising:

```swift
MHAppConfiguration(
    subscriptionProductIDs: ["premium.monthly"],
    nativeAdUnitID: adUnitID,
    adsConsent: .init()
)
```

- The runtime waits for premium status. Premium users see no consent form and
  trigger no ads SDK work.
- For other users it requests fresh consent information, presents a
  form only when the SDK requires one, and starts ads only when the SDK reports
  that ads can be requested. Consent from an earlier session starts ads while
  the update runs. Fresh eligibility is applied before a required form finishes.
  If premium becomes active during the update, the form is deferred until premium
  ends. Cancelled evaluations stop further work and can be retried explicitly.
- Reserve ad placements with `canDisplayAds` rather than `adsAvailability`;
  `adsConsentStatus` reports the consent side.
- When `adsPrivacyOptionsRequirement == .required`, show a control that calls
  `presentAdsPrivacyOptions()`.
- A failed update falls back to the SDK's stored state. Call
  `refreshAdsConsent()` to retry; the runtime does not retry on its own.
- If the app removes unknown keys from its standard defaults domain, add
  `MHAdsConsentStorage.currentDescriptors()` from `MHAppRuntimeAds` to the
  cleanup allowlist. Otherwise stored consent is erased on every launch.

Apps keep ownership of AdMob Privacy & messaging, regional policy, the under-age
tag, ATT, and disclosures. Use `debugGeography` only in debug builds.

## Documentation Map

Read these first when choosing products or integrating a consumer:

- [Consumer Boundaries](Designs/Architecture/consumer-boundaries.md):
  normative consumer matrix.
- [Consumer Adoption](Designs/Architecture/adoption-policy.md):
  product-selection rationale and current shell preferences.
- [Minimal App Setup](Designs/Architecture/minimal-app-setup.md): compact app
  bootstrap path.
- [Integration Contracts](Designs/Architecture/integration-contracts.md):
  module-by-module public contracts.
- [Preference Migration](Designs/Architecture/preference-migration.md):
  descriptor-first adoption, startup ordering, and explicit defaults overrides.

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
  want the default runtime, core primitives, optional UI bridges, mutation
  shell, logging bridge, and review shells from one import.
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

Granular core-safe products, optional UI bridges, and optional shells:

- `MHDeepLinking`
- `MHLogging`
- `MHLoggingUI`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHNotificationDeepLinking`
- `MHRouteExecution`
- `MHPersistenceMaintenance`
- `MHPreferences`
- `MHPreferencesUI`
- `MHUserNotifications`
- `MHMutationFlow`
- `MHMutationLogging`
- `MHReviewPolicy`
- `MHReviewRequesting`
- `MHReviewFlow`

Test support:

- `MHPlatformTesting`

## Boundary Rules

- `MHPlatform` remains a thin convenience umbrella over concrete modules.
- `MHPlatformCore` must not pull in `MHAppRuntime`, app-root runtime adapters,
  SwiftUI/UI bridge targets, StoreKit, ads, licenses, mutation workflow, or
  review policy.
- `MHAppRuntime` owns reusable runtime/bootstrap mechanics, not StoreKit, ads,
  license, or app-specific side-effect policy.
- `MHPreferences` and `MHLogging` own core primitives; `MHPreferencesUI` and
  `MHLoggingUI` own optional SwiftUI/UI bridge surfaces.
- `MHNotificationPayloads` owns platform-agnostic payload codecs and route
  resolution; `MHUserNotifications` owns UserNotifications adapters;
  `MHNotificationDeepLinking` owns notification-to-deep-link delivery helpers.
- `MHReviewPolicy` owns pure review policy; `MHReviewRequesting` owns direct
  platform requesting; `MHReviewFlow` owns runtime/mutation workflow wiring.
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
- `OptionalShellConsumer` proves review/mutation shells stay opt-in.
- `SurfaceAdapterConsumer` proves the widget, App Intent, watch, and extension
  adapter path using only granular products without app-runtime dependencies.

Package tests and integration tests cover the module behavior behind those
consumer paths. `Example/MHPlatformExample/` remains the full-umbrella demo app.

## Current Adoption Snapshot

- Incomes and Cookle currently adopt MHPlatform primarily through the umbrella
  `MHPlatform` product in app composition targets.
- `MHAppRuntime` is the shared runtime/startup surface used by app targets.
- `MHRouteExecution`, `MHDeepLinking`, `MHNotificationPlans`,
  `MHNotificationPayloads`, `MHUserNotifications`,
  `MHNotificationDeepLinking`, `MHPreferences`, `MHLogging`,
  `MHMutationFlow`, `MHReviewPolicy`, `MHReviewRequesting`, and
  `MHReviewFlow` provide reusable infrastructure while route meanings,
  mutation effects, notification copy, review timing, and platform side
  effects stay app-owned.
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

The shared `MHPlatformExample` scheme enables the local
`Example/MHPlatformExample/Configuration/Products.storekit` catalog for its Run
action. Run the example from Xcode to load the sample monthly subscription and
explore premium status and ad suppression with StoreKit Testing. The catalog
uses local test transactions; it does not require App Store Connect products.

The native ad demo uses Google's official test ad unit. Its app ID and
`SKAdNetworkItems` are configured in `Example/MHPlatformExample-Info.plist`
following
[Google's setup guide](https://developers.google.com/admob/ios/quick-start).
Adopting apps must supply their own app IDs and ad configuration.

## Requirements

- An Xcode toolchain with Swift 6.2 support and SDKs for the target platforms.
- Minimum deployment targets: iOS 18, macOS 15, and watchOS 11.
- SwiftPM package resolution for the repository-managed SwiftLint plugin used
  by retained rule scripts.

## Setup

1. Clone the repository and open the project directory.
2. Open `Package.swift` in Xcode if you want package browsing and test support.
3. Open `Example/MHPlatformExample.xcodeproj` if you want to run the demo app
   shell.
4. Use the helper scripts in `ci_scripts/tasks/` for repeatable local
   verification.

## Build and Test

Use Xcode and the Xcode-native integration available in the agent environment
for build, test, run, runtime-log, Preview, live UI, and screenshot evidence.
Follow the selection and restoration contract in `AGENTS.md`.

For MHPlatform package compile and test checks, select
`.swiftpm/xcode/package.xcworkspace`, the `MHPlatform-Package` scheme, and a
discovered iPhone Simulator destination, then use the available Xcode-native
build or test capability.

For example app compile or runtime checks, select
`Example/MHPlatformExample.xcodeproj`, the `MHPlatformExample` scheme, and a
discovered iPhone Simulator destination, then use the available Xcode-native
build or run capability. For package umbrella compile checks, use
`.swiftpm/xcode/package.xcworkspace`, the `MHPlatform` scheme, and a
discovered compatible iOS or watchOS Simulator destination.

The remaining helper scripts in `ci_scripts/` are retained for repository
rules and compatibility wrappers that are not naturally covered by the
available Xcode-native integration.

The retained scripts resolve SwiftLint from the `SwiftLintPlugins` package
declared in `Package.swift`; they do not require a separately installed
`swiftlint` binary on `PATH`.

Before running retained script checks, diagnose local prerequisites:

```sh
bash ci_scripts/tasks/check_environment.sh --profile rules
```

After Swift edits, run the explicit autofix step:

```sh
bash ci_scripts/tasks/format_swift.sh
```

For retained repository rule checks:

```sh
bash ci_scripts/tasks/check_repository_rules.sh
```

This retained rule entry point runs SwiftLint, the models-directory consistency
check, and consumer fixture checks.

If you prefer to run SwiftLint directly through the repository wrapper:

```sh
bash ci_scripts/tasks/format_swift.sh
bash ci_scripts/tasks/lint_swift.sh
```

Compatibility wrappers remain available for older local habits and push hooks:

```sh
bash ci_scripts/tasks/verify_task_completion.sh
bash ci_scripts/tasks/verify_repository_state.sh
bash ci_scripts/tasks/verify_pre_push.sh
bash ci_scripts/tasks/verify.sh
```

The aggregate shell build and package-test wrappers are kept for fallback use
when the Xcode-native integration is unavailable or does not cover a required
check:

```sh
bash ci_scripts/tasks/build_app.sh
bash ci_scripts/tasks/test_shared_library.sh
bash ci_scripts/tasks/run_required_builds.sh
```

## CI Artifact Layout

Compatibility aggregate scripts write generated artifacts under `.build/ci/`.
Run-scoped outputs are stored in `.build/ci/runs/<RUN_ID>/` (`summary.md`,
`commands.txt`, `meta.json`, `logs/`, `results/`, `work/`) when a wrapper uses
the run artifact helper. Shared caches and build state live in
`.build/ci/shared/` (`cache/`, `DerivedData/`, `tmp/`, `home/`).
