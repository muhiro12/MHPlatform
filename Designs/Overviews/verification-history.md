# MHPlatform Verification History

This document is intentionally durable guidance, not a manually maintained run
log.
Actual verification history lives under `.build/ci/runs/<RUN_ID>/`.

## Standard Entry Points

Use these repository entry points:

- `bash ci_scripts/tasks/verify_task_completion.sh`
- `bash ci_scripts/tasks/verify_repository_state.sh`

`verify_task_completion.sh` is the full task-completion gate for clean
checkouts, local implementation work, and CI-equivalent validation.
`verify_repository_state.sh` is the change-based repository-state gate for
local diff-focused work.
`verify.sh` remains only as a legacy compatibility wrapper around the full
task-completion gate.
`run_required_builds.sh` remains the internal incremental planner used by the
repository-state gate.

## Apple Runtime Evidence

MHPlatform intentionally retains shell verification for SwiftLint, SwiftPM
tests, consumer fixture builds, example-project builds, repository-specific
static rules, and run artifacts.
When a change needs live Apple runtime, Simulator, screenshot, UI snapshot, or
Xcode-specific evidence, use XcodeBuildMCP or official Apple tooling in
addition to the retained repository gate.

## Run Artifact Layout

Each verification run writes a directory under `.build/ci/runs/<RUN_ID>/` with
these artifacts:

- `summary.md`
- `commands.txt`
- `meta.json`
- `logs/`
- `results/`
- `work/`

Only the newest 5 run directories are retained.
The entire `.build/ci/` directory is disposable and should be treated as
generated state.

## How To Inspect A Run

1. Open the newest `.build/ci/runs/<RUN_ID>/summary.md`.
2. Use `commands.txt` to see the exact command order.
3. Inspect `logs/` for stdout and stderr details when a step fails.
4. Open `results/` when `xcodebuild` or other result bundles are referenced in
   the summary.

## Documentation Policy

- Do not record mutable command history, placeholder values, or per-phase run
  notes in tracked Markdown files.
- Use versioned docs for stable workflow guidance only.
- Use `.build/ci/runs/` as the source of truth for actual execution history.
