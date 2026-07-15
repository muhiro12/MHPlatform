# MHPlatform Verification History

This document is intentionally durable guidance, not a manually maintained run
log.
The Xcode-native integration available in the agent environment owns Apple
build, test, runtime-log, Preview, live UI, and screenshot evidence.
Compatibility shell run history lives under `.build/ci/runs/<RUN_ID>/` when a
fallback wrapper uses the run artifact helper.

## Xcode-Native Verification Contract

Resolve current actions by capability from the runtime tool inventory. Follow
the active-selection capture and restoration contract in the repository
`AGENTS.md`; do not encode a volatile namespace or action name here.

For package compile checks:

- Capability: Xcode-native build
- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform-Package`
- Destination: a discovered iPhone Simulator

For package tests:

- Capability: Xcode-native test
- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform-Package`
- Destination: a discovered iPhone Simulator

For example app compile or runtime evidence:

- Capability: Xcode-native build or bounded run with runtime-log review
- Project: `Example/MHPlatformExample.xcodeproj`
- Scheme: `MHPlatformExample`
- Destination: a discovered iPhone Simulator

For package umbrella compile evidence:

- Capability: Xcode-native build
- Workspace: `.swiftpm/xcode/package.xcworkspace`
- Scheme: `MHPlatform`
- Destination: a discovered compatible iOS or watchOS Simulator

## Retained Shell Checks

Run retained repository rules with:

```sh
bash ci_scripts/tasks/check_repository_rules.sh
```

`check_repository_rules.sh` runs SwiftLint, the models-directory consistency
check, and consumer fixture checks that are not naturally covered by
the available Xcode-native integration.

The following scripts are compatibility wrappers around retained repository
rules:

- `bash ci_scripts/tasks/verify_task_completion.sh`
- `bash ci_scripts/tasks/verify_repository_state.sh`
- `bash ci_scripts/tasks/verify_pre_push.sh`
- `bash ci_scripts/tasks/verify.sh`

The aggregate shell build and package-test wrappers remain fallback tools when
the Xcode-native integration is unavailable or does not cover a required
check:

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
