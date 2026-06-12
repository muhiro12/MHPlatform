# AGENTS.md

This document defines the repository-specific agent contract for MHPlatform.
Global agent behavior and durable cross-repository developer principles belong
outside this repository.

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

- Follow the repository SwiftLint configuration.
- Avoid abbreviated variable names such as `res`, `img`, and `btn`.
- Use `.init(...)` when the return type is explicit.
- Do not use single-line bodies for control-flow statements or trailing
  closures.

## Verification Contract

Agents must use this full task-completion entry point before finishing
implementation work:

```sh
bash ci_scripts/tasks/verify_task_completion.sh
```

Use this supplemental repository-state entry point when only change-based checks
are needed:

```sh
bash ci_scripts/tasks/verify_repository_state.sh
```

`ci_scripts/tasks/verify.sh` is a legacy compatibility wrapper around the full
task-completion gate. Do not document it as the primary entry point for new
work.

If a local push hook is desired, use this optional wrapper:

```sh
bash ci_scripts/tasks/verify_pre_push.sh
```

MHPlatform intentionally retains shell verification for SwiftLint, SwiftPM
tests, consumer fixture builds, example-project builds, repository-specific
static rules, and `.build/ci/runs/<RUN_ID>/` artifacts. When work requires live
Apple runtime, Simulator, screenshot, UI snapshot, or Xcode-specific evidence,
prefer XcodeBuildMCP or official Apple tooling in addition to the retained
repository gate.

CI run artifacts are written under `.build/ci/runs/<RUN_ID>/`. Each run stores
`summary.md`, `commands.txt`, `meta.json`, `logs/`, `results/`, and `work/`.
Shared CI directories are under `.build/ci/shared/` (`cache/`, `DerivedData/`,
`tmp/`, `home/`). Only the newest 5 run directories are retained. The entire
`.build/ci` directory is disposable.
