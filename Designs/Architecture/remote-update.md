# Remote Update Infrastructure

## Boundary from Existing Adopters

Issue [#15](https://github.com/muhiro12/MHPlatform/issues/15) extracts repeated
infrastructure from the current Incomes and Cookle implementations.

| Concern | Incomes today | Cookle today | Package boundary |
| --- | --- | --- | --- |
| Version ordering | Foundation string numeric ordering | One to three ASCII integer components, zero-padded | Preserve both contracts explicitly |
| Activation | Always when a required version is present | Inclusive start/end, maximum 72 hours | Optional validated interval with an app-supplied maximum |
| Publication | No lookup | Minimum must be public in the selected storefront | Optional publication gate and identity-validated lookup |
| Request failure | Throw; retain previously loaded configuration | Clear update flag and fail open | Expose failure and unavailable evidence; app chooses recovery |
| Presentation | App-owned alert | App-owned alert | No UI or copy |

`MHRemoteUpdate` is a standalone Foundation-only product. Apps, shared libraries,
and App Intent-style adapters can depend on it without an app-root runtime.
It has no dependency on either umbrella or on mutation/UI frameworks.

The package owns version validation/comparison, activation-window validation,
update decisions, lookup, and the opt-in scheduled-policy format, persistence,
and refresh orchestration. Apps own deployment URLs, legacy JSON adapters,
identifiers, storefronts, evidence lifetimes, storage locations, refresh triggers,
logging, protected operations, unavailable handling, and UI.
No app release values or repository URLs become package defaults.

## Version Contracts

`MHAppVersion` accepts one to three nonempty ASCII integer components that fit
in `Int`. It rejects whitespace, signs, suffixes, extra components, and overflow.
Missing components are zero; leading zeroes have no significance.

`MHAppVersionComparison.numericStringsRequireUpdate` preserves Foundation
`String.compare(options: .numeric)` for existing string-based policies.
It does not validate or zero-pad strings. For example, `1` and `1.0` are equal as
`MHAppVersion` values but differ under Foundation string ordering.
Replacing one contract with the other requires an explicit adopter decision.

## Decision Contract

`MHRemoteUpdatePolicy` accepts a validated minimum, an optional activation
window, and an explicit publication requirement. Activation includes both
endpoints. Zero, reversed, nonfinite, and excessive windows are rejected at
construction, using the maximum supplied by the app.

Evaluation returns `updateRequired`, `notRequired`, or `unavailable`.
An inactive policy or an installed version meeting the minimum returns
`notRequired`. Missing publication evidence, or a public version below the
minimum, returns `unavailable` for an otherwise active requirement. This deliberate
change prevents an unpublished update being treated as permission for protected
operations; mapping only `updateRequired` to an alert still preserves Cookle UI.

## Public Version Lookup and Evaluation

`MHAppStoreVersionLookup(session:)` uses the official
[ID-based Lookup API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html).
Its caller supplies the app ID, expected bundle identifier, and two-letter
storefront country code. A 2xx HTTP response, decodable result, matching app ID
and bundle ID, and valid numeric version are all required. The session can be
injected for request configuration and deterministic `URLProtocol` tests.
Transport, HTTP, decoding, and identity errors remain observable to the app.
Lookup confirms storefront metadata, not that every device can download an update.

`MHRemoteUpdateEvaluator` accepts installed-version, clock, and async public-version
providers. The app fetches and decodes its own configuration first. The evaluator
has no remote-config endpoint, schema, storage, runtime, or UI dependency. It skips
unneeded publication requests and evaluates time again after a lookup completes.
Missing policy or an invalid installed version yields `unavailable`; lookup errors
throw, allowing the app to log and explicitly select recovery. Cancellation throws
`CancellationError` rather than producing an update decision.

## Legacy Adoption and Deliberate Policy Migration

### Incomes

1. Add the `MHRemoteUpdate` product to the shared library.
2. Replace `VersionComparator` / `RemoteConfigurationOperations` comparison with
   `MHAppVersionComparison.numericStringsRequireUpdate(currentVersion:minimumVersion:)`.
   Keep the existing operations facade if app adapters depend on it.
3. Keep `.config.json`, `requiredVersion` decoding, bundle/playground checks,
   logging, and alert state in the app. Preserve the existing fetch-error behavior,
   including previously loaded configuration remaining available after a failed
   refresh. A missing configuration/version must not become a validated decision.
4. Do not silently add a window, publication lookup, stricter parsing, or normalized
   missing components. Those are separate product changes requiring app approval.

The existing Incomes numeric-ordering tests and unequal-component-count cases are
covered by the shared comparison tests. The typed evaluator is available for a
future deliberately chosen policy migration, rather than a prerequisite for this
behavior-preserving extraction.

### Cookle

1. Add the `MHRemoteUpdate` product to the shared library or app adapter as needed.
   Replace `AppVersion` with `MHAppVersion`.
2. Decode the existing optional `forceUpdate` document in the app. Construct
   `MHUpdateActivationWindow` with the existing app-owned maximum of 72 hours;
   reject invalid windows. Construct `MHRemoteUpdatePolicy` with
   `requiresPublicVersion: true` and that interval.
3. Replace reusable lookup plumbing with `MHAppStoreVersionLookup(session:)`.
   Pass the existing app ID, injected expected bundle identifier, and country.
   Preserve the app's playground exclusion before making a request.
4. Inject the existing installed-version and clock providers into
   `MHRemoteUpdateEvaluator`; its public-version closure calls the lookup.
5. Preserve `isUpdateRequired = false` before refresh and map only
   `updateRequired` to `true`. An absent `forceUpdate` means no requirement in
   Cookle's schema; malformed policy or failed lookup remains distinguishable
   internally even when the app presents neither as an update alert.
   Handle cancellation without applying an obsolete async result.

Neither app has been migrated by this package change. Move adoption separately
with each app's library tests and surface verification. The scheduled controller
below is an intentional policy migration, including publication confirmation for
Incomes; it is not the behavior-preserving comparator substitution above. No
package version bump, Store release, or remote policy activation is required for
local extraction.

## Protected Operations

`decision.checkOperationAllowed(whenUnavailable:)` is a synchronous, throwing
precondition with no runtime or UI dependency. The app must explicitly choose
`allow` or `block` for unavailable evidence. A validated `updateRequired` decision
always throws. This primitive does not choose which operations are protected.

Place the check in the app's shared operation entry point used by UI and App
Intents, before starting the mutation workflow and all success side effects:

```swift
try decision.checkOperationAllowed(whenUnavailable: appUnavailableBehavior)
try await performMutationAndSuccessEffects()
```

Refresh/re-evaluate immediately before a protected operation according to app-owned
freshness and offline policy. A decision is a snapshot, not a durable permission or
an atomic guarantee against a policy changing during an operation. Do not cache a
successful check as ongoing authorization. Map fetch errors to an app-owned error
or `unavailable`, never implicitly to a validated `notRequired` result.

`Fixtures/Consumers/SurfaceAdapterConsumer/` decodes its own sample schema and uses
this same precondition for UI/App Intent-style callers without runtime products.
Its tests verify that a blocked operation performs neither mutation nor success
side effects, and that unavailable evidence follows the explicit caller choice.

This support does not retrofit enforcement into already-distributed binaries.
It is not retroactive migration, CloudKit, or old-writer compatibility protection.
Apps still decide protected operations, enforcement rollout, unavailable-policy
handling, and presentation before adopting enforcement.

## Scheduled Policy and Retained Evidence

`MHRemoteUpdateSchedule` is an optional shared wire contract, independent of
legacy `.config.json` formats. Its schema version describes the format; its
positive `revision` identifies an immutable operational change, not an app release.
All changes, including postponement, renewal, and cancellation, increase revision.
Unknown fields are ignored; unsupported schema versions, malformed versions,
missing requirement keys, invalid identity, and invalid dates are rejected.
An explicit `requirement: null` confirms no update requirement. Missing data,
HTTP failures, and decode failures never mean cancellation.

```json
{
  "schemaVersion": 1,
  "bundleIdentifier": "com.example.app",
  "revision": 12,
  "issuedAt": "2026-10-18T00:00:00Z",
  "validUntil": "2026-11-08T00:00:00Z",
  "requirement": {
    "minimumVersion": "6.0",
    "effectiveAt": "2026-11-01T00:00:00Z"
  }
}
```

These are illustrative values, not a production policy. Remote timestamps use
ISO 8601 UTC seconds. `MHRemoteUpdateSchedule.decode(_:)` and `encoded()` implement
this format. A requirement may also have an optional inclusive `endsAt`.

| Field or evidence | Meaning |
| --- | --- |
| `issuedAt` through exclusive `validUntil` | When the entire policy document can be trusted, including cancellation |
| `effectiveAt` through optional inclusive `endsAt` | When the requirement applies, while the document remains valid |
| Publication `checkedAt` through exclusive `validUntil` | How long a successful storefront observation remains usable |
| App-selected maximum validity and publication age | Local upper limits, reapplied when reading retained evidence |

The two-week lead time does not require a two-week enforcement window. The legacy
72-hour Cookle window is an app-owned constraint for its existing adapter; the
new schedule has independent activation and evidence validity. Neither lifetime
gets a package default. A policy expiring, or publication missing, below minimum,
or expired, produces `unavailable`, never `notRequired`. A valid future
requirement is `notRequired` until activation; a version meeting the minimum is
also `notRequired` while the policy document remains valid.

## Controller and Operation Entry Points

`MHRemoteUpdateController` is one actor per app, environment, and storefront.
It re-evaluates installed version and time on every `decision()` or operation
check. There is no app-root runtime dependency, timer, UI, or automatic mutation.

The following assembly belongs to the app. The identifiers, URL, lifetimes,
cache directory, providers, and refresh triggers must be supplied by that app:

```swift
let policyLookup = MHRemoteUpdateScheduleLookup(session: session)
let storeLookup = MHAppStoreVersionLookup(session: session)
let updates = try MHRemoteUpdateController(
    bundleIdentifier: bundleIdentifier,
    storefront: storefront,
    maximumValidity: maximumPolicyValidity,
    publicationLifetime: publicationLifetime,
    store: .init(fileURL: policyCacheURL),
    currentVersion: installedVersion,
    fetchSchedule: {
        try await policyLookup.schedule(from: policyURL, bundleIdentifier: bundleIdentifier)
    },
    publicVersion: {
        try await storeLookup.version(
            appID: appID, bundleIdentifier: bundleIdentifier, country: storefront
        )
    }
)
```

Create the storage parent directory first. Call `restore()` once at startup,
handle/log any error, and retain the controller so a corrupt or absent cache
leaves usable unknown state. Call `refresh()` at app-selected startup,
foreground, retry, or other refresh points; handle errors without replacing them
with permission. Refresh also checks publication before future activation so
usable publication evidence can be retained ahead of time.

A valid schedule is saved before publication lookup. Failed/cancelled lookups
preserve prior evidence until its own expiry; successful observations replace
publication evidence. A successful lookup yielding nil clears publication proof,
not the schedule. Only matching bundle and storefront evidence can be restored.
A higher revision cannot be rolled back, and changed content at the same revision
is rejected. The latest refresh invocation supersedes older in-flight responses.
A save error is thrown while the latest accepted evidence remains in memory.

Use the shared app operation entry point called by UI, App Intents, and other
surfaces. For example, an app can choose:

| App operation | Unavailable behavior | Refresh if unavailable |
| --- | --- | --- |
| Side-effect-free browsing | `allow` | `false` |
| App-designated consequential save | `block` | `true` |
| Consequential operation with separate retry UI | `block` | `false` |

```swift
try await updates.checkOperationAllowed(
    whenUnavailable: .block,
    refreshIfUnavailable: true
)
try Task.checkCancellation()
try await performMutationAndSuccessEffects()
```

Refresh occurs at most once per check, only from unavailable state. Errors
propagate before the operation begins. If refresh succeeds but evidence remains
unavailable, the explicit allow/block choice applies. Known required updates
block all these normal operation paths; provide separate retry and Store routes.
A required state does not itself trigger refresh through this check.

`SurfaceAdapterConsumer` demonstrates both legacy primitives and the scheduled
controller at a common operation boundary. Its tests verify low-impact offline
use, one refresh before consequential operations, and no mutation or success
effects on rejection. Operation classification remains app-owned.

## Release Operations Independent of Source Releases

Both existing apps currently fetch `main/.config.json`. This couples a live
operational policy change to the next source release, regardless of the file's
name or its JSON schema. Putting a new schema at that same URL alone does not
remove this coupling.

For new adopters, use a stable endpoint backed by separately maintained policy
history. A policy-only branch in the app repository is sufficient; a separately
hosted configuration repository or service can use the same contract. A policy
branch should contain only deployable policy documents and should not be merged
into the app's source branch. The package never chooses or creates a hosting
repository, branch, or URL.

A 6.0 rollout then has separate histories:

1. Finish and tag the app's 6.0 source commit. No live policy change is needed in
   that commit, and the 6.1 source branch can evolve independently.
2. Publish a higher policy revision at the independent endpoint. It can announce
   6.0 before release, with a future activation time and sufficient validity.
3. Before activation, clients keep the plan across launches. If 6.0 is already
   active in the policy but not confirmed public, their state is unavailable:
   low-impact operations may continue while consequential operations wait.
4. Once activation and valid publication evidence both hold, older versions
   require an update. Installed 6.0 meets the minimum and continues normally.
5. Postponement, cancellation, and validity renewal are policy-history commits;
   they do not become 6.1 source changes. Each uses a higher revision. A
   cancellation is a full valid document with `requirement: null`.

Publication gating prevents a premature *update-required* state; an active
unpublished requirement can still limit consequential operations. Use future
activation when announcing a release in advance. Renewal must occur before
expiry to keep confirming either requirement or cancellation; absence of renewal
intentionally becomes unavailable. HTTP caches cannot extend absolute validity.

An offline device cannot learn an unreceived cancellation or a new emergency
requirement. Shorter evidence lifetimes reduce stale enforcement but increase
unknown periods; apps choose this tradeoff explicitly. Device clock changes can
also affect local evaluation; this is not a trusted server-time mechanism.

### Migration Boundary for Existing Binaries

Already-distributed Incomes versions still read their hard-coded legacy URL and
have no publication gate. A new JSON document or new package cannot retrofit
these binaries. Keep the legacy endpoint and its `requiredVersion` compatible;
do not raise it to 6.0 before 6.0 is available. A final legacy `main/.config.json`
change may therefore still be needed after release during transition.

Ship adoption of the independent endpoint and shared schedule in an earlier
compatible app release when advance announcements are needed for a later
release. Cookle also needs deliberate adoption of retained evidence and
operation gating rather than only mapping the decision to an alert. Neither
app, legacy endpoint, live policy, nor hosting branch is changed by this package
implementation. Each adoption requires its own operation classification,
lifetimes, cache path, deployment endpoint, and app verification.
