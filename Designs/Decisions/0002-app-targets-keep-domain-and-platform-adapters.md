# ADR 0002: App Targets Keep Domain and Platform Adapters

- Date: 2026-03-10
- Status: Accepted

## Context

Apps adopting MHPlatform still own route semantics, product configuration,
notification text, widget behavior, watch behavior, and other platform-specific
or product-specific decisions. Moving those policies into MHPlatform would blur
the boundary between reusable infrastructure and app-owned meaning.

## Decision

Keep app-specific domain and platform adapters in the app targets. MHPlatform
provides reusable shells and primitives, but route enums, mutation result
metadata, Apple-framework side effects, and app-specific follow-up policy stay
outside the package.

## Consequences

- Apps map their own route and mutation result types into MHPlatform APIs.
- Package modules stay app-agnostic even when they provide higher-level shells.
- When a new feature needs Apple-only APIs or product-specific policy, the
  default design is an app-side adapter over package primitives.
