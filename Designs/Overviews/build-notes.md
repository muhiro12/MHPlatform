# MHPlatform Build Notes

## Start State

- Workspace root: `<workspace-root>` (the parent directory of `MHPlatform/`, containing `MHPlatform/`, `Incomes/`, and `Cookle/`)
- Git repository used for all git operations: `MHPlatform/`
- Initial branch: `main`
- Initial working tree status: not clean (the ongoing MHPlatform refactor edits were already in progress)

## Commands Run

All build and lint commands below were run inside `MHPlatform/`:

1. `git status --short --branch`
2. `swiftlint lint --strict`
3. `swiftlint lint --strict --no-cache`
4. `swift test`
5. `swiftlint lint --strict --no-cache`
6. `swift test`
7. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
8. `swiftlint lint --strict --no-cache`

Workspace-root read-only verification commands:

1. `find Incomes -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_incomes_after.sha256`
2. `find Cookle -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_cookle_after.sha256`
3. `diff -u <temporary-directory>/mhplatform_incomes_before.sha256 <temporary-directory>/mhplatform_incomes_after.sha256`
4. `diff -u <temporary-directory>/mhplatform_cookle_before.sha256 <temporary-directory>/mhplatform_cookle_after.sha256`

## Results

- `swiftlint lint --strict --no-cache`: passed with `0` violations
  - `swiftlint lint --strict` also reported `0` violations, but exited non-zero in this environment because SwiftLint could not write its cache plist
- `swift test`: passed
  - 25 tests across 4 suites passed
- `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - `appintentsmetadataprocessor` reported metadata extraction was skipped because there is no `AppIntents.framework` dependency (non-fatal)

## Read-only Verification

- `Incomes/`: no file hash changes detected (`diff` returned no output)
- `Cookle/`: no file hash changes detected (`diff` returned no output)
- All implementation changes remain under `MHPlatform/`

## Commit

- Commit message: `Add deep linking notification plans and mutation flow`
- Final commit hash: `TO_BE_FILLED_AFTER_COMMIT`

## MHPreferences Phase

### Start State

- Branch: `main`
- `git status --short --branch`:

```text
## main
```

### Commands Run

All commands below were run inside `MHPlatform/`:

1. `swiftlint lint --strict --no-cache`
2. `swift test`
3. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
4. `swiftlint lint --strict --no-cache`

Workspace-root read-only verification commands:

1. `find Incomes -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_incomes_after.sha256`
2. `find Cookle -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_cookle_after.sha256`
3. `diff -u <temporary-directory>/mhplatform_incomes_before.sha256 <temporary-directory>/mhplatform_incomes_after.sha256`
4. `diff -u <temporary-directory>/mhplatform_cookle_before.sha256 <temporary-directory>/mhplatform_cookle_after.sha256`

### Results

- `swiftlint lint --strict --no-cache`: passed with `0` violations
- `swift test`: passed
  - 39 tests across 6 suites passed
- `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - `appintentsmetadataprocessor` reported metadata extraction was skipped because there is no `AppIntents.framework` dependency (non-fatal)

### Read-only Verification

- `Incomes/`: no file hash changes detected (`diff` returned no output)
- `Cookle/`: no file hash changes detected (`diff` returned no output)
- All implementation changes remain under `MHPlatform/`

## MHPreferences Finalization Pass

### Start State

- Branch: `main`
- Working tree: not clean (in-progress `MHPreferences` edits already present)

### Commands Run

All commands below were run inside `MHPlatform/`:

1. `git status --short --branch`
2. `swiftlint lint --strict --no-cache`
3. `swift test`
4. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
5. `swiftlint lint --strict --no-cache`
6. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
7. `swiftlint lint --strict --no-cache`
8. `swift test`
9. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
10. `swiftlint lint --strict --no-cache`
11. `git status --short --branch`

Workspace-root read-only verification commands:

1. `find <workspace-root>/Incomes -type f -newermt '2026-03-05 09:00:00' | head`
2. `find <workspace-root>/Cookle -type f -newermt '2026-03-05 09:00:00' | head`
3. `find MHPlatform Incomes Cookle -type f -newermt '2026-03-05 09:00:00' | awk -F/ '{print $1}' | sort -u`

### Results

- `swiftlint lint --strict --no-cache`: passed with `0` violations
- `swift test`: passed
  - 39 tests across 6 suites passed
- First `xcodebuild ... build`: failed (missing closing brace in `PreferencesDemoView`)
- Second `xcodebuild ... build`: failed (iOS-only `textInputAutocapitalization` modifier)
- Final `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - non-fatal warning remains in `MutationFlowDemoView` for main-actor isolation on event recorder call

### Read-only Verification

- `find` checks for `Incomes/` and `Cookle/` returned no recently modified files
- Cross-directory change check returned only `MHPlatform`

## MHNotificationPayloads Phase

### Start State

- Branch: `main`
- `git status --short --branch`:

```text
## main
```

### Commands Run

All commands below were run inside `MHPlatform/`:

1. `swiftlint lint --strict --no-cache`
2. `swift test`
3. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
4. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
5. `swiftlint lint --strict --no-cache`

Workspace-root read-only verification commands:

1. `find Incomes -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_incomes_before.sha256`
2. `find Cookle -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_cookle_before.sha256`
3. `find Incomes -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_incomes_after.sha256`
4. `find Cookle -type f -print0 | sort -z | xargs -0 shasum -a 256 > <temporary-directory>/mhplatform_cookle_after.sha256`
5. `diff -u <temporary-directory>/mhplatform_incomes_before.sha256 <temporary-directory>/mhplatform_incomes_after.sha256`
6. `diff -u <temporary-directory>/mhplatform_cookle_before.sha256 <temporary-directory>/mhplatform_cookle_after.sha256`

### Results

- First `swiftlint lint --strict --no-cache`: failed (new file-name and ordering violations in `MHNotificationPayloads` additions)
- Second `swiftlint lint --strict --no-cache`: passed with `0` violations
- First `swift test`: failed (URL validity assumptions in new codec tests)
- Second `swift test`: passed
  - 55 tests across 9 suites passed
- First `xcodebuild ... build`: failed (access-level issue in `NotificationPayloadsDemoView`)
- Second and final `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - non-fatal `appintentsmetadataprocessor` warning remains (metadata extraction skipped without `AppIntents.framework`)

### Read-only Verification

- `Incomes/`: no file hash changes detected (`diff` returned no output)
- `Cookle/`: no file hash changes detected (`diff` returned no output)
- All implementation changes remain under `MHPlatform/`

## MHRouteExecution Phase

### Start State

- Branch: `main`
- `git status --short --branch`:

```text
## main
```

### Commands Run

All commands below were run inside `MHPlatform/`:

1. `swift test`
2. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
3. `swiftlint lint --strict --no-cache`
4. `swift test`
5. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
6. `swiftlint lint --strict --no-cache`
7. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`

### Results

- First `swift test`: failed (`MHRouteExecutionTests` variable redeclaration)
- Second and final `swift test`: passed
  - 63 tests across 10 suites passed
- First `xcodebuild ... build`: failed (`RouteExecutionDemoView` Combine import and main-actor/sendable isolation issues)
- Second and final `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - non-fatal `appintentsmetadataprocessor` warning remains (metadata extraction skipped without `AppIntents.framework`)
- First `swiftlint lint --strict --no-cache`: failed (`one_declaration_per_file`, `type_contents_order`, and related style violations)
- Second and final `swiftlint lint --strict --no-cache`: passed with `0` violations

### Scope Verification

- Added new `MHRouteExecution` module and tests under `MHPlatform/` only
- Added `RouteExecutionDemoView` and support files in `Example/MHPlatformExample/`
- Updated architecture/backlog/readme/build notes docs in `MHPlatform/Docs` and `MHPlatform/README.md`

## MHPersistenceMaintenance Phase

### Start State

- Branch: `main`
- `git status --short --branch`:

```text
## main
```

### Commands Run

All commands below were run inside `MHPlatform/`:

1. `swift test`
2. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
3. `swiftlint lint --strict --no-cache`
4. `swift test`
5. `xcodebuild -project Example/MHPlatformExample.xcodeproj -scheme MHPlatformExample -destination 'generic/platform=macOS' build`
6. `swiftlint lint --strict --no-cache`
7. `bash ci_scripts/tasks/run_required_builds.sh`
8. `swiftlint lint --strict --no-cache`
9. `bash ci_scripts/tasks/run_required_builds.sh`

### Results

- `swift test`: passed
  - 71 tests across 12 suites passed
- `xcodebuild ... build`: passed
  - `MHPlatformExample.app` built successfully for macOS
  - non-fatal `appintentsmetadataprocessor` warning remains (metadata extraction skipped without `AppIntents.framework`)
- `swiftlint lint --strict --no-cache`: passed with `0` violations
- First `bash ci_scripts/tasks/run_required_builds.sh`: failed (new `implicit_return` violation in `MHDestructiveResetService`)
- Final `bash ci_scripts/tasks/run_required_builds.sh`: passed
  - `swift test` passed
  - `xcodebuild ... build` passed
  - `swiftlint lint --strict --no-cache` passed

### Scope Verification

- Added new `MHPersistenceMaintenance` module and tests under `MHPlatform/Sources` and `MHPlatform/Tests`
- Added `PersistenceMaintenanceDemoView` and updated `ContentView` in `Example/MHPlatformExample/`
- Added standardized `ci_scripts/tasks/run_required_builds.sh` for MHPlatform
- Updated `README.md`, `Designs/Architecture/architecture.md`,
  `Designs/Overviews/backlog.md`, and `.swiftlint.yml`
