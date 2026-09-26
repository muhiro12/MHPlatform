# Descriptor-first Preference Migration

Use this guide when moving a key-based integration, including a 1.5.x-era
integration, to the current descriptor-first API. Follow the current public
surface rather than treating historical initializer spellings as compatibility
APIs. See [Integration Contracts](integration-contracts.md#mhpreferences) for
the normative storage rules.

## Choose the Integration Surface

| Need | Product and entry point |
| --- | --- |
| Non-UI reads and writes | `MHPreferences`, `MHPreferenceStore` |
| SwiftUI bindings | `MHPreferencesUI`, `AppStorage` descriptor initializers |
| Codable bindings | `MHCodablePreference`, `MHOptionalCodablePreference` |
| Descriptor-driven migration and cleanup | `MHPreferenceLifecycleService` |
| App-owned schema and synchronous startup | `MHPreferenceRegistry` |
| Custom migration | `MHPreferenceMigrationService` |
| Shared-library umbrella | `MHPlatformCore` |
| Full application umbrella, including UI bridges | `MHPlatform` |

Import `MHPreferences` alongside `MHPreferencesUI` when using the granular
products. `MHPlatformCore` exports preferences but does not export the SwiftUI
bridges. Keep app-root runtime dependencies out of widgets and shared libraries;
follow the [consumer matrix](consumer-boundaries.md).

Descriptors, stores, lifecycle outcomes, migration events, and cleanup reports
are integration APIs. `MHPreferenceDescriptors` is an optional namespace for
app-defined key paths; it is not a registry and does not discover descriptors.
Domain normalization, generated move-step identifiers, and storage-resolution
helpers are implementation details; do not reproduce them in application code.

## Preserve the Persisted Contract

1. Inventory the final keys and defaults domains already shipped to users.
2. Replace key declarations with typed descriptors. Supply the exact final
   `storageKey` and an explicit `defaultSelection` for each descriptor.
3. Preserve the previous stored representation and fallback value. Changing a
   Swift declaration alone does not migrate existing data.
4. Declare `legacySources` only for actual key or domain moves. Use custom
   migration steps for representation changes.
5. Enumerate every current slot before enabling unknown-key cleanup, including
   raw keys owned by other libraries and both logging snapshot slots.

```swift
import MHPreferences

enum AppPreferences {
    static let notificationsEnabled = MHBoolPreferenceDescriptor(
        storageKey: "notifications.enabled",
        defaultSelection: .standard,
        legacySources: [
            .init(storageKey: "legacy.notifications", selection: .standard)
        ],
        default: true
    )
    static let migrationState = MHPreferenceMigrationStateDescriptor(
        storageKey: "preferences.completedMigrations",
        defaultSelection: .standard
    )
    static let current: [any MHStorageDescriptorProtocol] = [
        notificationsEnabled
    ]
}
```

Built-in moves preserve an existing destination. The lifecycle service migrates
first and then removes unknown keys from all touched domains, including legacy
domains. Its descriptor list is a complete cleanup allowlist, not just the
preferences changed in this release. Register externally owned exact keys as
`MHRawStorageDescriptor` values. Avoid whole-domain cleanup when the app cannot
enumerate the domain's owners. A reported migration failure skips cleanup;
validate legacy Codable data before migration because the convenience Codable
read returns `nil` for missing or undecodable data.

Logging uses `MHLogSnapshotStorageDescriptors` with explicit `current` and
`previous` descriptors. Preserve the actual historical keys when retaining their
contents; the package does not append suffixes. Converting an older snapshot
representation requires an app-owned migration before logging starts.

## Keep External Keys and Inspect Cleanup

Use raw descriptors as an explicit cleanup exclusion list. For dynamic keys,
obtain the exact current keys from their owner and map them to raw descriptors
before running lifecycle work. Do not derive this list from all keys already in
the defaults domain: that would also preserve stale keys.

```swift
let externalKeys = ["external.feature-state"]
let externalDescriptors = externalKeys.map { storageKey in
    MHRawStorageDescriptor(storageKey: storageKey, defaultSelection: .standard)
}
let descriptors: [any MHStorageDescriptorProtocol] =
    AppPreferences.current + externalDescriptors
```

Pass the combined array to `MHPreferenceLifecycleService.run`. Raw descriptors
protect the exact key in their selected domain and imply no migration steps.
For the lower-level cleanup service, `domainName` selects the domain; the
caller must supply only that domain's known descriptors.

Each lifecycle cleanup report identifies its `selection` and `domainName`.
The nested report includes sorted `knownStorageKeys` and `removedStorageKeys`:
every removed key was present in that persistent domain and absent from its
allowlist. The allowlist includes the migration-state descriptor in its own
domain, deduplicates keys, and is reported even when the domain is empty.
No preference values are included. Key names may still contain app data;
apply the app's logging policy before exporting diagnostics.

## Run Lifecycle Work Before Preference Consumers

Stored-property and property-wrapper initialization happens before the body of
`App.init()`. An app-level `@AppStorage` declaration can therefore access its
defaults before lifecycle code placed in that initializer. A `Task` launched
from `App.init()` also does not block subsequent reads. A view's `.task` runs
after that view has been constructed.

Collect the complete current descriptor set and migration-state slot in an
`MHPreferenceRegistry`. Registry construction performs no defaults access.
For built-in moves, run synchronously before constructing preference consumers:

```swift
let registry = MHPreferenceRegistry(
    descriptors: AppPreferences.current,
    migrationStateDescriptor: AppPreferences.migrationState
)
let startupOutcome = registry.runSynchronously()
```

Inspect `startupOutcome.migrationOutcome` before continuing startup. This runs
on the caller's thread, with no `Task`, semaphore, or hidden defaults override.
Keep work small; a synchronous migration can delay app startup. Calling it in
`App.init()` does not move it ahead of that app's stored-property initializers.
Keep preference wrappers in a child constructed after successful preparation,
or explicitly initialize their backing storage after preparation.

Custom descriptors can return `MHPreferenceMigrationStep.synchronous(id:action:)`
steps. An unfinished async-only step returns
`MHPreferenceSynchronousMigrationError.asynchronousStep` before any step runs
or cleanup occurs. Already-completed async-only steps remain skippable. A
throwing synchronous step stops the run; successful earlier steps remain
recorded, and cleanup is skipped. This is ordered migration, not a transaction.

For genuinely asynchronous migration, use `await registry.run()` or the
lower-level lifecycle service. Use an app-owned loading state that does not
read preferences, await completion, inspect the outcome, and only then
construct the settings-dependent root view and runtime services. Keep
preference wrappers in the gated child, not in the `App` or loading root.

```swift
let outcome = await MHPreferenceLifecycleService.run(
    descriptors: AppPreferences.current,
    migrationStateDescriptor: AppPreferences.migrationState
)
switch outcome.migrationOutcome {
case .succeeded:
    // Publish readiness on the UI actor; then construct preference consumers.
    break
case .failed:
    // Keep consumers gated and present the app's recovery or retry flow.
    break
}
```

Serialize lifecycle execution per defaults domain. Coordinate app extensions
that share an app-group suite; the service is not a cross-process lock. Keep
the migration-state key stable across launches. Do not block a thread with a
semaphore to turn the asynchronous API into a synchronous initializer.

## Choose AppStorage or Direct Store Access

Use descriptor-based `AppStorage` for small settings that need SwiftUI bindings:

```swift
import MHPreferences
import MHPreferencesUI
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.notificationsEnabled) private var isEnabled

    var body: some View {
        Toggle("Notifications", isOn: $isEnabled)
    }
}
```

Use `MHPreferenceStore` in non-UI logic and startup work. Use its
`codableResult` and `setCodableResult` APIs when decoding or encoding failure
must remain visible. Codable preferences store JSON as `Data`; they do not
automatically convert previously stored property-list objects. The UI Codable
wrappers are convenience bindings with fallback behavior, not a migration
error-reporting interface.

## Use Bare-member Enum Shorthand

Keep the enum as the source of descriptor definitions and expose an app-owned
static alias on the concrete descriptor type. The existing concrete AppStorage
initializers can infer both the descriptor and the wrapped value:

```swift
enum BoolPreference: MHBoolPrefDescriptorRepresentable {
    case isDebugOn

    var preferenceDescriptor: MHBoolPreferenceDescriptor {
        .init(storageKey: "debug.enabled", defaultSelection: .standard)
    }
}

extension MHBoolPreferenceDescriptor {
    static var isDebugOn: Self {
        BoolPreference.isDebugOn.preferenceDescriptor
    }
}

struct DebugSettingsView: View {
    @AppStorage(.isDebugOn) private var isDebugOn

    var body: some View {
        Toggle("Debug", isOn: $isDebugOn)
    }
}
```

This retains the enum's descriptor and default selection. Use
`MHIntPreferenceDescriptor` and `MHStringPreferenceDescriptor` aliases for the
corresponding enum-backed preferences. Int representables construct a descriptor
with an explicit default; preserve the intended fallback in that alias.
Explicit `store:` overrides remain available on all three concrete types.

Give aliases the visibility needed by their call sites and avoid competing
aliases with the same name in the same scope. Without aliases, qualify the
representable case as `BoolPreference.isDebugOn`. Key paths rooted at
`MHPreferenceDescriptors` remain another supported option.

Swift also supports [constrained protocol static lookup][static-member-lookup],
but forwarding a protocol alias to an identically named enum case makes that
reference ambiguous. Concrete descriptor aliases avoid this collision and do
not require a new wrapper or changes to the enum's case names.

[static-member-lookup]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0299-extend-generic-static-member-lookup.md

## Defaults Ownership and Explicit Overrides

Each descriptor carries its production defaults selection so UI, background
work, shared libraries, and extensions agree without first constructing an
app runtime. Runtime configuration does not install a hidden global defaults
override. An unbound `MHPreferenceStore()` resolves each descriptor separately.

For previews and tests, create an isolated suite and explicitly inject the same
`UserDefaults` into `MHPreferenceStore(userDefaults:)` and each UI bridge's
`store:` parameter. Descriptor-based AppStorage initializers pass a concrete
store to SwiftUI; do not rely on `.defaultAppStorage` to redirect them.
Remove only the temporary test domain during teardown.

When a selection is already available, use `MHPreferenceStore(selection:)`.
For deep-link handoff, use `MHDeepLinkStore(selection:key:)` with the exact
persisted key, or `MHDeepLinkStore(key:)` with a raw descriptor:

```swift
import MHDeepLinking
import MHPreferences

let selection = MHUserDefaultsSelection.suite("group.com.example.app")
let preferences = MHPreferenceStore(selection: selection)
let pendingLinks = MHDeepLinkStore(selection: selection, key: "pendingURL")
```

These bound stores use the selection's existing validation. If configuration
can be invalid, call `selection.makeUserDefaults()` first and handle `nil`
before using the `userDefaults:` initializer. An invalid suite never silently
falls back to standard defaults. The same explicit injection pattern applies
to runtime services receiving these stores.

A bound store redirects all descriptors used through that store. It does not
rewrite descriptor selections or the lifecycle service's cleanup targets.
For lifecycle tests, construct descriptors, legacy references, and migration
state in isolated test suites as well; a store override alone does not isolate
cleanup. For an app group, use `.suite("group.com.example.app")` on the relevant
descriptors and configure the app and extension entitlements separately.
