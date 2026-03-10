# ADR 0001: MHPlatform Source of Truth for Shared App Infrastructure

- Date: 2026-03-10
- Status: Accepted

## Context

Incomes and Cookle share non-domain app infrastructure such as runtime
bootstrap, route handoff, notification planning, review triggers, logging, and
preferences. When those concerns are reimplemented in each app, integration
behavior drifts and maintenance cost rises.

## Decision

`MHPlatform` is the canonical source of truth for reusable non-domain app
infrastructure shared across apps. Runtime, routing primitives, mutation
workflow shells, logging, preferences, and persistence maintenance belong in
this package when they are proven reusable.

## Consequences

- Shared infrastructure should be extracted into MHPlatform before new app-side
  forks are introduced.
- The package should stay modular and concern-specific rather than growing a
  generic core layer.
- App repositories should depend on package APIs instead of recreating the same
  reusable orchestration locally.
