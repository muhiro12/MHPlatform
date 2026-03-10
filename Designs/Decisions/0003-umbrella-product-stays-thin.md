# ADR 0003: Umbrella Product Stays Thin

- Date: 2026-03-10
- Status: Accepted

## Context

The `MHPlatform` umbrella product is convenient for adopters, but convenience
modules often become dumping grounds for unrelated logic. That would make
boundaries harder to understand and reduce the value of the concrete module
products.

## Decision

Keep the `MHPlatform` umbrella target thin and convenience-oriented.
New reusable behavior belongs in concrete modules such as `MHAppRuntime`,
`MHRouteExecution`, or `MHMutationFlow`, or in a new focused module when a new
responsibility genuinely appears.

## Consequences

- Apps may choose between umbrella adoption and granular module adoption.
- Public API organization stays understandable from module names.
- Test helpers and other non-production surfaces should remain outside the
  umbrella unless they are intentionally part of production adoption.
