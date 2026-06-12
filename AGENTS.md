# AGENTS.md

This document defines the repository-specific agent contract for MHPlatform.

## Repository Scope

- MHPlatform is an app-agnostic Swift package foundation for reusable
  Apple-platform infrastructure.
- Keep app-specific domain business logic, route meanings, notification copy,
  mutation result schemas, widget policy, watch policy, and App Intent behavior
  in adopting apps.
- Treat Incomes and Cookle as read-only reference material when they are used
  for boundary evidence. Do not copy app-specific Operations or domain logic
  into MHPlatform.
- Public repository documents, comments, identifiers, and branch names must use
  English unless UI localization or legal content requires otherwise.

## Package Boundary Rules

- Keep `MHPlatform` as the full app-facing convenience umbrella.
- Keep `MHPlatformCore` safe for shared libraries, widgets, App Intents,
  lightweight watch surfaces, and extension adapters that only need core
  primitives.
- Keep `MHAppRuntime` as the advanced app-root runtime/bootstrap surface.
- Prefer granular products when a consumer only needs one focused concern.
- Keep widget, App Intent, watch, and extension adapters thin over app-owned
  shared APIs first; use MHPlatform directly only for reusable platform
  primitives.
- Do not add ads, license, runtime, review, or app-root dependencies to surface
  adapters only for convenience.
- Use `Designs/Architecture/consumer-boundaries.md` as the normative consumer
  matrix before changing product dependencies.

## Documentation Rules

- Keep `README.md` as the portable product and adoption entry point.
- Put durable architecture policy under `Designs/Architecture/`.
- Put durable decisions under `Designs/Decisions/`.
- Keep short-term planning out of public docs unless it becomes a durable
  repository decision.
- All Markdown files must follow:
  <https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md>

## Swift Code Rules

Swift code must follow the repository SwiftLint configuration and existing
source style.

## Verification Contract

Agents MUST prefer XcodeBuildMCP for Apple build, test, run, Simulator, runtime
log, screenshot, and UI snapshot verification.

Before the first XcodeBuildMCP build, test, or run call in a session, run
XcodeBuildMCP `session_show_defaults`. If defaults do not point at MHPlatform,
set them for the current session instead of relying on shell wrappers.

For package compile checks, use XcodeBuildMCP `build_sim` with:

- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform-Package`
- Simulator: an available iPhone simulator

For package tests, use XcodeBuildMCP `test_sim` with the same workspace and
scheme.

For example app compile or runtime checks, use XcodeBuildMCP `build_sim` or
`build_run_sim` with:

- Project: `Example/MHPlatformExample.xcodeproj`
- Scheme: `MHPlatformExample`
- Simulator: an available iPhone simulator

For package umbrella compile checks through the example project, use the same
project with the `MHPlatform` scheme.

Agents should also run the retained repository rule checks:

```sh
bash ci_scripts/tasks/check_repository_rules.sh
```

`check_repository_rules.sh` runs SwiftLint, the models-directory consistency
check, and consumer fixture checks that are not naturally covered by
XcodeBuildMCP.

`verify_task_completion.sh`, `verify_repository_state.sh`, `verify_pre_push.sh`,
and `verify.sh` are compatibility wrappers around retained repository rules.
Direct shell build and package-test scripts are compatibility or fallback tools;
do not treat them as the primary agent verification surface when MCP is
available.

Compatibility scripts may write disposable data under `.build/ci/shared/` or
`.build/ci/runs/<RUN_ID>/`.
