# MHPlatform Verification History

This document is intentionally durable guidance, not a manually maintained run
log.
Actual verification history lives under `.build/ci/runs/<RUN_ID>/`.

## Standard Entry Points

Use one of these repository entry points:

- `bash ci_scripts/tasks/verify.sh`
- `bash ci_scripts/tasks/run_required_builds.sh`

`verify.sh` is the full verification path for clean checkouts and CI.
`run_required_builds.sh` is the incremental path for local diff-based work.

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
