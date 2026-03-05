# MHKit North Star

MHKit is shared application infrastructure extracted from concrete duplication in
Incomes and Cookle. It is intentionally small, Apple-native, and module-flat.

## Why MHKit Exists

- Provide cross-app infrastructure that repeats across apps but is not
  app-domain logic.
- Keep reusable infrastructure in one place so app targets can stay focused on
  product behavior and platform adapters.
- Make shared behavior deterministic and testable without introducing a generic
  core architecture.
- Preserve each app domain library (`IncomesLibrary`, `CookleLibrary`) as the
  owner of domain models and rules.

## What MHKit Intentionally Avoids

- Domain rules and domain model ownership:
  finance, recipe, and app-specific business decisions stay in each domain
  library.
- UI state stores and presentation coordination:
  screen state, sheet state, focus state, and view navigation state stay in app
  targets.
- Persistence abstraction over SwiftData:
  no repository/service abstraction that hides `ModelContext`, SwiftData
  semantics, or app-specific storage policy.

## Apple-Native Compatibility Stance

- SwiftUI remains the first-class UI layer.
- Observation remains the first-class state observation model.
- SwiftData remains the first-class persistence model.
- App Intents remain first-class adapter entry points.
- WidgetKit remains first-class for glanceable surfaces.
- MHKit is additive glue around these APIs, not a replacement architecture.

## Decision Matrix: Domain Library vs App Adapter vs MHKit

| Decision Rule | Belongs In | Examples |
| --- | --- | --- |
| Domain behavior tied to app entities | Domain Library | `ItemService`, `RecipeService` |
| Target-only framework adaptation | App Adapter | widget reload, review prompt, `openURL` |
| Cross-app infra with no domain ownership | MHKit | deep-link codec, route coordinator |
| Screen and navigation presentation state | App Adapter | view models, sheet/focus flags |
| Deterministic planning from pure models | MHKit | reminder/suggestion planners |
| App schema and migration policy decisions | Domain or App Adapter | migration checks |

## v1 Boundary Guardrails

- Keep module dependencies flat:
  public MHKit modules do not depend on each other.
- Do not introduce `MHCore` or an umbrella runtime module in v1.
- Prefer extracting concrete duplicated concerns, not speculative abstractions.
- Keep app-domain behavior in app domain libraries, even when names look
  similar across apps.

## Naming Convention (Canonical)

Canonical naming for outcomes, events, planners, and handoff storage terms is
defined in [`CONTRACTS.md`](CONTRACTS.md#naming-convention-decision). This run
adopts an Outcome-first policy at documentation level with no source-breaking
renames.
