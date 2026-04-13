# ADR 0005: Keep Preferences UserDefaults-Based and SwiftUI Wrappers Layered

- Date: 2026-04-14
- Status: Accepted

## Context

`MHPreferences` gradually accumulated multiple ways to talk about the same
preference system:

- `UserDefaults` as the persistence backend
- `MHPreferenceStore` as the non-SwiftUI typed access path
- `AppStorage` and codable property wrappers as SwiftUI-facing bindings

Recent refactors improved descriptor ownership and lifecycle orchestration, but
the surrounding naming and documentation started to drift toward treating
`AppStorage` as the main concept rather than the SwiftUI wrapper.

That creates two problems:

- it blurs the boundary between a `UserDefaults`-backed persistence model and a
  SwiftUI property-wrapper surface
- it weakens the role of `MHPreferenceStore`, cleanup, and lifecycle APIs,
  which are not `AppStorage` concerns

## Decision

Treat `MHPreferences` as a typed preference layer backed by `UserDefaults`.

- `MHPreferenceStore` is the canonical non-SwiftUI access path.
- `AppStorage`, `MHCodablePreference`, and `MHOptionalCodablePreference` are
  SwiftUI wrappers layered over the same descriptors.
- Public API naming remains centered on `Preferences` rather than being renamed
  to `UserDefaults`.
- The concrete key-path namespace root is renamed from `MHPreferenceKeys` to
  `MHPreferenceDescriptors`, because it exposes descriptors rather than keys.

## Consequences

- Documentation and comments should describe `UserDefaults` as the persistence
  backend and `AppStorage` as the SwiftUI wrapper layer.
- Apps should use `MHPreferenceStore` for migration, cleanup, boot logic, and
  other non-view persistence code.
- SwiftUI code should use `@AppStorage`, `@MHCodablePreference`, and
  `@MHOptionalCodablePreference` as view-facing bindings over descriptors.
- The repository should avoid reintroducing language that treats `AppStorage`
  as the persistence model itself.
