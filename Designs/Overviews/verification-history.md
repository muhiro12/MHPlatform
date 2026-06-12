# MHPlatform Verification History

This document is intentionally durable guidance, not a manually maintained run
log.
XcodeBuildMCP owns MCP build, test, runtime, screenshot, and UI evidence.
Compatibility shell run history lives under `.build/ci/runs/<RUN_ID>/` when a
fallback wrapper uses the run artifact helper.

## MCP-First Verification Contract

Use XcodeBuildMCP as the standard evidence surface for Apple build, test, run,
Simulator, runtime log, screenshot, and UI snapshot verification.

For package compile checks:

- XcodeBuildMCP `build_sim`
- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform-Package`
- Simulator: an available iPhone simulator

For package tests:

- XcodeBuildMCP `test_sim`
- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform-Package`
- Simulator: an available iPhone simulator

For example app compile or runtime evidence:

- XcodeBuildMCP `build_sim` or `build_run_sim`
- Project: `Example/MHPlatformExample.xcodeproj`
- Scheme: `MHPlatformExample`
- Simulator: an available iPhone simulator

Use the `MHPlatform` scheme from `Example/MHPlatformExample.xcodeproj` when the
package umbrella needs an example-project compile check.

## Retained Shell Checks

Run retained repository rules with:

```sh
bash ci_scripts/tasks/check_repository_rules.sh
```

`check_repository_rules.sh` runs SwiftLint, the models-directory consistency
check, and consumer fixture checks that are not naturally covered by
XcodeBuildMCP.

The following scripts are compatibility wrappers around retained repository
rules:

- `bash ci_scripts/tasks/verify_task_completion.sh`
- `bash ci_scripts/tasks/verify_repository_state.sh`
- `bash ci_scripts/tasks/verify_pre_push.sh`
- `bash ci_scripts/tasks/verify.sh`

The aggregate shell build and package-test wrappers remain fallback tools when
MCP is unavailable or when a check is not yet covered by the available MCP tool
surface:

- `bash ci_scripts/tasks/build_app.sh`
- `bash ci_scripts/tasks/test_shared_library.sh`
- `bash ci_scripts/tasks/run_required_builds.sh`

## Run Artifact Layout

Compatibility aggregate scripts may write directories under
`.build/ci/runs/<RUN_ID>/` with these artifacts:

- `summary.md`
- `commands.txt`
- `meta.json`
- `logs/`
- `results/`
- `work/`

Only the newest 5 run directories are retained by scripts that use the run
artifact helper.
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
