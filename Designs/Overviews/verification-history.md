# MHPlatform Verification History

This document is intentionally durable guidance, not a manually maintained run
log.
The Xcode-native integration available in the agent environment owns Apple
build, test, runtime-log, Preview, live UI, and screenshot evidence.
Compatibility shell run history lives under `.build/ci/runs/<RUN_ID>/` when a
fallback wrapper uses the run artifact helper.

## Xcode-Native Verification Contract

Resolve current actions by capability from the runtime tool inventory. Follow
[Build and Test](../../README.md#build-and-test) for selection capture,
restoration, and boundary-based evidence selection; do not encode a volatile
namespace or action name here.

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

## StoreKit Integration Evidence

Use the example app's shared `MHPlatformExample` scheme and its local
`Configuration/Products.storekit` launch configuration to exercise the standard
runtime and subscription section. Open the `MHAppRuntime` demo and observe
`Premium Status` before and after each action, without restarting the app.
Keep the default StoreKit view completion handling and avoid app-owned
entitlement readers or injected purchase callbacks in this verification path.

- With no active test subscription, confirm inactive status. Cancel a purchase
  and confirm it stays inactive, then complete a purchase and confirm active
  status and premium ad suppression in the same process.
- Exercise Restore Purchases. Distinguish an already-active no-op restore from
  a restore that actually recovers access. If the environment cannot produce
  missing local entitlement information, record the latter as unverified.
- When supported by the StoreKit test environment, exercise failed purchases,
  pending approval and subsequent approval, expiration, and revocation. Check
  that pending or failed attempts do not falsely grant access or revoke existing
  verified access. Record unavailable scenarios rather than inferring success.
- Keep runtime callback tests separate: they cover initial and subsequent
  snapshots, configured product matching, and isolation from a released or
  replaced runtime. They do not establish transaction verification, StoreKit view
  delivery, refresh ordering inside StoreKitWrapper, or App Store restoration.

Retain the source revision and working diff, resolved MHPlatform/StoreKitWrapper
revisions, Xcode version, OS destination, StoreKit configuration, initial purchase
state, observed transitions, screenshots, and runtime logs with the run artifacts.
Local StoreKit results do not replace Sandbox/device qualification of a consumer.
Follow the [subscription contract](../Architecture/integration-contracts.md#subscription-entitlement-propagation)
when deciding whether an app-owned refresh workaround can be removed.

## Retained Shell Checks

Run retained repository rules with:

```sh
bash ci_scripts/tasks/check_repository_rules.sh
```

`check_repository_rules.sh` runs SwiftLint and the five consumer fixture
checks that are not naturally covered by the available Xcode-native integration.
Its rules path does not require ripgrep. The separate compatibility build
wrapper still uses ripgrep for warning-log searches.

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
