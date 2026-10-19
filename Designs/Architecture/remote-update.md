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

`MHRemoteUpdate` is a Foundation-only module re-exported by `MHPlatformCore`
and therefore `MHPlatform`. Existing umbrella adopters need no extra product.
The standalone product remains available for focused consumers and has no
dependency on either umbrella or on mutation/UI frameworks.

The package owns version validation/comparison, activation-window validation,
update decisions, lookup, and the opt-in scheduled-policy format, persistence,
and refresh orchestration, including standard App Store assembly and defaults.
Apps supply the deployment URL and Store ID, publish release policy, identify
protected operations, connect lifecycle entry points, and own UI/logging.
Legacy adapters and exceptional overrides remain available through advanced APIs.
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
Its caller supplies the app ID and expected bundle identifier, with an optional
two-letter storefront country code. A 2xx HTTP response, decodable result, matching app ID
and bundle ID, and valid numeric version are all required. The session can be
injected for request configuration and deterministic `URLProtocol` tests.
Transport, HTTP, decoding, and identity errors remain observable to the app.
Local HTTP cache is bypassed, so a repeated lookup cannot renew cached metadata
as freshly observed publication evidence.
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

## Remote Policy and Retained Evidence

`MHRemoteConfigDocument<Features>` owns the shared app configuration envelope.
`MHRemoteUpdateSchedule.Feature` owns the `features.remoteUpdate` section.
Its policy is edited only when the release decision changes; it has no publisher
renewal period. This minimal document confirms no update requirement:

```json
{
  "schemaVersion": 1,
  "bundleIdentifier": "com.example.app",
  "features": {
    "remoteUpdate": {
      "revision": 1,
      "requirement": null
    }
  }
}
```

A planned release uses the same format with a requirement and a higher revision:

```json
{
  "schemaVersion": 1,
  "bundleIdentifier": "com.example.app",
  "features": {
    "remoteUpdate": {
      "revision": 2,
      "requirement": {
        "minimumVersion": "6.0",
        "effectiveAt": "2026-11-01T00:00:00Z"
      }
    }
  }
}
```

The values above are illustrative. `schemaVersion` describes the format; the
positive `features.remoteUpdate.revision` identifies an immutable update decision, independent
of app versions. Changes, postponement, and explicit cancellation require a
higher revision. The same revision with different content and older revisions
are rejected, including after retained evidence expires. Each document replaces
the previous single current or future requirement.

Activation uses absolute ISO 8601 UTC seconds; an optional inclusive `endsAt`
ends the requirement. Construction and decoding normalize dates down to whole
seconds before validating intervals. Intervals that collapse at this precision
are rejected. `decode(_:)` and `encoded()` implement the shared wire format.

Only explicit `requirement: null` cancels a requirement. Omission, malformed
versions, invalid identity, invalid dates, unsupported schemas, HTTP errors, and
missing data never mean cancellation or validated permission. Authored
`issuedAt` and `validUntil` fields in the update section are not accepted: freshness belongs to the
fetched evidence rather than to the release decision.

### Shared Entry Point and Feature Boundaries

`MHRemoteConfigClient` accepts the app's HTTPS URL, validates the response and
app identity, and decodes a typed feature payload through the common envelope.
No owner, repository, app directory, or deployment URL is built into the package.
The standard update initializer uses this client through
`MHRemoteUpdateScheduleLookup`; it does not implement a second HTTP stack.

An app-wide configuration can later decode several selected feature sections in
one request and distribute that response to their processors. The envelope and
transport impose no update-specific revision, activation, expiry, or UI rules.
Only update processing is implemented.

The update-only decoder ignores unrelated feature sections, including values that
would be invalid for those features. Missing or null `features.remoteUpdate`
is an error, not cancellation. Changes to sibling sections do not change update
policy equality or require a higher update revision. A future multi-feature
decoder must isolate each feature's validation failure rather than throwing away
all otherwise valid sections.

`MHRemoteConfigResponse` carries the original network observation. Its `map`
selects a feature without renewing that time. The update controller accepts
`MHRemoteConfigResponse<MHRemoteUpdateSchedule>` and derives bounded evidence
from that observation, never from the later time a shared value is selected or
read from disk. Only validated update policy enters the update-specific store.
Shared transport does not force unrelated features to use the update policy's
30-day age limit or operation-blocking behavior.

`MHRemoteUpdateSchedule.decode(_:)` and `encoded()` read and write the common
remote envelope. Its `Codable` representation is the selected update model used
inside retained snapshots; it does not retain or republish unrelated sections.
Use an appropriate `MHRemoteConfigDocument<Features>` when publishing a complete
multi-feature configuration.

### Separate Freshness from Activation

| Information | Meaning and standard lifetime |
| --- | --- |
| Remote policy | Immutable release decision; no periodic publisher renewal |
| Policy observation | Accepted fetch time through exclusive expiry; at most 30 days of offline reuse |
| Activation through optional requirement end | When an update applies; independent of when the policy was fetched |
| App Store publication observation | Successful storefront lookup through exclusive expiry; 24 hours |

A successful, identity-validated network fetch renews policy evidence even when
revision and JSON have remained unchanged for months. The standard lookup
bypasses local HTTP cache. Every `prepare()` attempts refresh; the standard
operation check refreshes once when evidence is unavailable. No publisher job,
service, timer, or periodic JSON edit is required.

Local restore, failed/malformed fetches, identity or revision conflicts, and
cancelled responses never renew freshness. Offline expiry becomes `unavailable`,
including for cancellation and compliant installed versions; expiry never grants
permission. The current local maximum age is reapplied to restored observations.
A failed refresh keeps only evidence that remains valid on its own terms.

A successful policy fetch does not itself renew App Store evidence. Publication
must be observed separately. A future requirement is `notRequired` before
activation; a compliant installed version also returns `notRequired` while policy
evidence remains fresh. Otherwise an active requirement needs unexpired proof
that the minimum version is public, or its result is `unavailable`.

## Controller and Operation Entry Points

`MHRemoteUpdateController` is one actor per app, environment, and storefront.
It re-evaluates installed version and time on every `decision()` or operation
check. There is no app-root runtime dependency, timer, UI, or automatic mutation.

### Standard App Store Adoption

The standard path requires only the app's operational endpoint and App Store ID:

```swift
import MHPlatformCore

let updates = try MHRemoteUpdateController(
    appStoreID: appStoreID,
    configurationURL: configurationURL
)
let preparation = try await updates.prepare()
```

Call `prepare()` from the app's startup and foreground hooks. It restores until
evidence initializes, then refreshes on each invocation. A failed cache read is
retried on the next call unless restoration or refresh has initialized evidence.
A corrupt cache does not prevent a fetch; a fetch failure does not discard
still-valid evidence. The result contains
`decision`, `restorationError`, and `refreshError` so the app can update UI and
log diagnostics without reimplementing recovery sequencing. Cancellation throws.
No timer, lifecycle observer, or UI presentation is installed automatically.

| Standard behavior | Package convention |
| --- | --- |
| Identity and installed version | `Bundle.main`; pass the containing app's bundle in extensions |
| Metadata storefront | Omitted by default; set `storefront` for a specific publication reference |
| Offline policy evidence | 30 days from the latest accepted network fetch |
| Publication evidence lifetime | 24 hours |
| Persistence | Application Support / MHRemoteUpdate, scoped by bundle, Store ID, and country |
| Directory preparation | Created automatically when saving |
| Cache source identity | A different policy URL cannot reuse the cached evidence |
| Normal operation check | Require confirmation, refreshing once if unavailable |
| Low-impact offline operation | Explicit `.allowWhenUnavailable`, without networking |

The policy may supply an optional requirement end. The policy evidence lifetime
and publication lifetime are separate limits, not enforcement durations.
The shared defaults are MH integration conventions, not release values copied
from one app. `Defaults` exposes the standard constants.

The standard lookup omits the country parameter. Apple's service currently
defaults to the US storefront; omission is not a global catalog and does not
solve publication lookup for apps unavailable in the US. Such apps must select
an available reference storefront. Language and storefront are independent.
Default and explicitly selected storefronts have separate evidence files.

For a specific publication reference, pass the optional country code:

```swift
let updates = try MHRemoteUpdateController(
    appStoreID: appStoreID,
    configurationURL: configurationURL,
    storefront: "jp"
)
```

An optional `storageDirectory` supports shared containers, alternate environments,
and tests. Use separate directories/controllers for different environments.
One process owns each cache file; App Group writer coordination is not automatic.

### Advanced Assembly

The injectable initializer, explicit `restore()` / `refresh()`, and
allow/block plus refresh flags remain for tests, legacy migration, or concrete
exceptions. Standard apps do not need to assemble lookup closures, pick a cache
filename, create directories, or choose evidence lifetimes. Advanced persistence
uses one snapshot containing the policy, its fetched observation, storefront,
and publication evidence. Standard assembly scopes the snapshot to its source
URL. Do not read a standard cache as an unscoped snapshot. Missing observation
data is an invalid cache, never an implicit new fetch time.

A valid schedule is saved before publication lookup. Failed/cancelled lookups
preserve prior evidence until its own expiry; successful observations replace
publication evidence. A successful lookup yielding nil clears publication proof,
not the schedule. Only matching bundle and storefront evidence can be restored.
A higher revision cannot be rolled back, and changed content at the same revision
is rejected. The latest refresh invocation supersedes older in-flight responses.
A save error is thrown while the latest accepted evidence remains in memory.

Use the shared app operation entry point called by UI, App Intents, and other
surfaces. The standard API chooses confirmation unless explicitly relaxed:

```swift
try await updates.checkOperationAllowed()
try Task.checkCancellation()
try await performMutationAndSuccessEffects()
```

For app-designated low-impact operations only:

```swift
try await updates.checkOperationAllowed(for: .allowWhenUnavailable)
```

`.requireConfirmation` is the default. It refreshes at most once, only from
unavailable state. Fetch/save errors propagate before the operation begins; a
successful refresh with insufficient evidence still blocks. The relaxed rule
allows unavailable evidence without a request. A known required update blocks
both rules. Apps still decide which operations can use the relaxed rule and must
wire every protected entry point to the check. There is no automatic app lock.
Provide separate retry and Store routes; a required state does not itself trigger
refresh through this check.

`SurfaceAdapterConsumer` demonstrates both legacy primitives and the scheduled
controller at a common operation boundary. Its tests verify low-impact offline
use, one refresh before consequential operations, and no mutation or success
effects on rejection. Operation classification remains app-owned.

## Migrating from 1.17.0

Version 1.18.0 intentionally replaces the scheduled-controller API, remote wire
format, and retained snapshot before operational adoption. This is an explicit
minor-release exception, not a source- or wire-compatible upgrade. The legacy
version comparison, activation policy, evaluator, and operation-decision
primitives remain available.

| Integration boundary | Required change |
| --- | --- |
| Standard controller | Rename `policyURL:` to `configurationURL:`. |
| Metadata storefront | Pass `storefront: "jp"` to retain 1.17.0's Japan reference; omission now delegates to Apple's service default. |
| Remote JSON | Use the shared envelope shown above; move `revision` and explicit `requirement` under `features.remoteUpdate`. Remove authored `issuedAt` and `validUntil`. |
| Schedule construction | Remove `issuedAt:` and `validUntil:` from `MHRemoteUpdateSchedule` construction. |
| Advanced controller | Replace `maximumValidity:` with `policyLifetime:` for retained fetch evidence. `Defaults.maximumValidity` is replaced by `Defaults.policyLifetime`. |
| Injected schedule provider | Return `MHRemoteConfigResponse<MHRemoteUpdateSchedule>` with the original validated network observation. The standard lookup already returns this response; use `map` when selecting from a shared response. |
| Lookup error handling | Use `MHRemoteConfigError` for request, HTTP, envelope, and identity validation instead of `MHRemoteUpdateScheduleLookup.Failure`. Transport and decoding errors still propagate. |
| Advanced snapshot code | Supply the new policy `observation`; use `maximumPolicyAge:` when evaluating snapshots. |

The shared envelope still uses `schemaVersion: 1`; it does not accept or silently
reinterpret 1.17.0's flat bounded-document format. Do not replace a deployed
legacy endpoint with this format while old clients still consume it. Publish a
separate endpoint for new adopters when both formats must coexist.

There is no automatic migration of 1.17.0 retained snapshots. A missing cache
starts unavailable; an incompatible cache throws on `restore()`. `prepare()`
reports that restoration failure and still attempts a validated fetch. A
successful fetch writes the new snapshot; a failed fetch leaves the result
unavailable. Offline startup after this transition therefore cannot authorize
protected operations from old evidence. Never manufacture a fresh observation
timestamp from a disk read. These files contain replaceable configuration
evidence, not app-owned user data.

## Release Operations Independent of Source Releases

Fetching `main/.config.json` couples a live operational policy change to the next
source release, regardless of the file's name or JSON schema. Putting a new schema
at that same URL alone does not remove this coupling.

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
   6.0 before release, with a future activation time. The unchanged JSON remains
   usable on later successful fetches without publisher renewal.
3. Before activation, clients keep the plan across launches. If 6.0 is already
   active in the policy but not confirmed public, their state is unavailable:
   low-impact operations may continue while consequential operations wait.
4. Once activation and valid publication evidence both hold, older versions
   require an update. Installed 6.0 meets the minimum and continues normally.
5. Postponement and cancellation are policy-history commits; they do not become
   6.1 source changes. Each uses a higher revision. A cancellation is a full valid
   document with `requirement: null`. Re-fetching unchanged policy renews only
   the client's retained evidence; it needs no policy-history commit.

Publication gating prevents a premature *update-required* state; an active
unpublished requirement can still limit consequential operations. Use future
activation when announcing a release in advance. Policy evidence is renewed by
accepted network fetches; offline expiry intentionally becomes unavailable.
Local cache reads extend neither policy nor publication evidence.

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
implementation. Each adoption requires its own operational endpoint and Store ID, operation
classification, lifecycle/UI connection, and app verification. Standard lifetimes,
lookup assembly, cache placement, and recovery sequencing are package-owned;
override them only for a concrete app-specific requirement.
