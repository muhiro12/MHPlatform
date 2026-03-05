# MHKit Architecture

## Public Modules

- `MHDeepLinking`
- `MHNotificationPlans`
- `MHNotificationPayloads`
- `MHMutationFlow`
- `MHPreferences`

The package name is `MHKit`, but consumers import concrete module names instead of a single umbrella module.

## Platform Baseline

- iOS 18.0+
- macOS 15.0+

## Module Boundaries

### `MHDeepLinking`

- Owns URL grammar primitives:
  `MHDeepLinkConfiguration`, `MHDeepLinkDescriptor`, `MHDeepLinkCodec`
- Owns pending-route handoff primitives:
  `MHDeepLinkInbox`, `MHDeepLinkStore`
- Does not own app navigation state or route execution

### `MHNotificationPlans`

- Owns deterministic schedule planning:
  `MHReminderPlanner`, `MHSuggestionPlanner`
- Owns schedule input/output models:
  candidates, policies, plans, delivery time
- Does not own `UNNotificationRequest`, categories, authorization, or payload composition

### `MHNotificationPayloads`

- Owns routing-focused notification payload primitives:
  `MHNotificationPayload`, `MHNotificationRouteTargets`, `MHNotificationPayloadCodec`
- Owns action/category descriptors and route resolution:
  `MHNotificationActionDescriptor`, `MHNotificationCategoryDescriptor`, `MHNotificationRouteResolver`
- Provides optional `UserNotifications` bridge helpers behind `#if canImport(UserNotifications)`
- Does not own notification text templates, attachment generation, or
  `UNUserNotificationCenter` orchestration

### `MHMutationFlow`

- Owns mutation retry, cancellation, and post-success side-effect orchestration
- Exposes observable execution events through `MHMutationEvent`
- Does not own persistence, widgets, notifications, or review APIs directly

### `MHPreferences`

- Owns typed preference keys and `UserDefaults` read/write primitives
- Owns `AppStorage` bridge initializers for primitive preference keys
- Stores codable values as `Data` without legacy string-format fallback
- Does not define app-specific preference key names or policy

## Dependency Rules

- Module dependencies are intentionally flat for v1.
- `MHDeepLinking` has no dependency on the other modules.
- `MHNotificationPlans` has no dependency on the other modules.
- `MHNotificationPayloads` has no dependency on the other modules.
- `MHMutationFlow` has no dependency on the other modules.
- `MHPreferences` has no dependency on the other modules.
- ExampleApp may import all public modules, but package targets must stay independent.

## Why No Generic Core Layer

- The duplicated logic found in Incomes and Cookle is concrete and concern-specific.
- Introducing `MHCore`, `MHObservability`, or a generic workflow layer now would create abstraction before stable shared usage exists.
- If repeated low-level types emerge later, they can be extracted after at least two modules genuinely need them.

## Out Of Scope

- `UNUserNotificationCenter` orchestration adapters (registration, authorization, scheduling)
- SwiftUI navigation-state executors
- shared migration policy for existing app preference formats
- database migration and destructive reset helpers
- remote config
- a generic umbrella `MHKit` product

## Verification Expectations

- Changes stay inside `MHKit/`.
- `Incomes/` and `Cookle/` remain read-only reference material.
- `swift test` must pass.
- `MHKitExample` in `Example/` must build through `xcodebuild`.
