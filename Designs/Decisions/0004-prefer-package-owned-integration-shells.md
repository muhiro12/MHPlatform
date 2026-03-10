# ADR 0004: Prefer Package-Owned Integration Shells

- Date: 2026-03-10
- Status: Accepted

## Context

App repositories repeatedly need the same integration shapes: runtime startup,
deep-link replay, mutation follow-up sequencing, and review trigger wiring.
Handwritten app-local glue for those patterns drifts over time and weakens the
reason for sharing MHPlatform at all.

## Decision

Prefer package-owned integration shells when the same orchestration shape is
reused across multiple apps. `MHAppRuntimeBootstrap`, `MHRouteLifecycle`,
`MHMutationWorkflow`, and `MHReviewFlow` are the preferred shared entry points
for those concerns.

## Consequences

- Apps should keep the app-specific parts as closures, adapters, and value
  types around the package shells.
- When two apps repeat the same integration glue, the next step is to refine a
  package shell rather than adding another app-local wrapper.
- MHPlatform may add new focused shells, but only when they stay app-agnostic
  and do not absorb app-specific policy.
