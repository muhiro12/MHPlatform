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
An inactive policy, an installed version meeting the minimum, or a confirmed
public version below the minimum returns `notRequired`. Missing publication
evidence for an otherwise active requirement returns `unavailable`.
