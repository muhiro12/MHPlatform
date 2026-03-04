# MHKit Build Notes

## Start State

- Workspace root: `/Users/Hiromu/Repositories/MKKitFactory`
- Git repository used for all git operations: `MHKit/`
- Initial branch: `main`
- Initial working tree status: not clean (the ongoing MHKit refactor edits were already in progress)

## Commands Run

All build and lint commands below were run inside `MHKit/`:

1. `git status --short --branch`
2. `swiftlint lint --strict`
3. `swiftlint lint --strict --no-cache`
4. `swift test`
5. `swiftlint lint --strict --no-cache`
6. `swift test`
7. `xcodebuild -project Example/MHKitExample.xcodeproj -scheme MHKitExample -destination 'generic/platform=macOS' build`
8. `swiftlint lint --strict --no-cache`

Workspace-root read-only verification commands:

1. `find Incomes -type f -print0 | sort -z | xargs -0 shasum -a 256 > /tmp/mhkit_incomes_after.sha256`
2. `find Cookle -type f -print0 | sort -z | xargs -0 shasum -a 256 > /tmp/mhkit_cookle_after.sha256`
3. `diff -u /tmp/mhkit_incomes_before.sha256 /tmp/mhkit_incomes_after.sha256`
4. `diff -u /tmp/mhkit_cookle_before.sha256 /tmp/mhkit_cookle_after.sha256`

## Results

- `swiftlint lint --strict --no-cache`: passed with `0` violations
  - `swiftlint lint --strict` also reported `0` violations, but exited non-zero in this environment because SwiftLint could not write its cache plist
- `swift test`: passed
  - 25 tests across 4 suites passed
- `xcodebuild ... build`: passed
  - `MHKitExample.app` built successfully for macOS
  - `appintentsmetadataprocessor` reported metadata extraction was skipped because there is no `AppIntents.framework` dependency (non-fatal)

## Read-only Verification

- `Incomes/`: no file hash changes detected (`diff` returned no output)
- `Cookle/`: no file hash changes detected (`diff` returned no output)
- All implementation changes remain under `MHKit/`

## Commit

- Commit message: `Add deep linking notification plans and mutation flow`
- Final commit hash: `TO_BE_FILLED_AFTER_COMMIT`
