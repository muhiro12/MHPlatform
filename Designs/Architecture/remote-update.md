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
update decisions, and reusable App Store lookup. Apps own configuration URLs,
JSON schemas, identifiers, storefronts, maximum activation duration, logging,
refresh/caching policy, unavailable-policy handling, protected operations, and UI.
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

## Adoption Without Changing Release Policy

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
with each app's library tests and surface verification. No package version bump,
Store release, or remote policy activation is required for local extraction.

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
