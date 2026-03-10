#!/usr/bin/env bash
set -euo pipefail

argument_count=$#
if [[ $argument_count -ne 0 ]]; then
  echo "This script does not accept arguments." >&2
  exit 2
fi

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/../.." && pwd)
cd "$repository_root"

source "$repository_root/ci_scripts/lib/ci_runs.sh"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must run inside a git repository." >&2
  exit 1
fi

start_run "$repository_root"
echo "CI run artifacts: $RUN_ROOT"

start_epoch=$(date +%s)
start_time_display=$(date +"%Y-%m-%d %H:%M:%S %z")
start_time_iso=$(date +"%Y-%m-%dT%H:%M:%S%z")

overall_result="success"
run_note="Evaluating local changes to determine required CI steps for MHPlatform."
failed_step=""
failed_log=""
executed_steps=()

finalize_run_artifacts() {
  local exit_code=$1
  set +e

  local end_epoch
  local end_time_display
  local end_time_iso
  local duration_seconds
  local executed_steps_markdown

  end_epoch=$(date +%s)
  end_time_display=$(date +"%Y-%m-%d %H:%M:%S %z")
  end_time_iso=$(date +"%Y-%m-%dT%H:%M:%S%z")
  duration_seconds=$((end_epoch - start_epoch))

  if [[ $exit_code -ne 0 ]]; then
    overall_result="failure"
    if [[ "$run_note" == "Evaluating local changes to determine required CI steps for MHPlatform." || "$run_note" == "Executed required CI steps for MHPlatform based on local changes." ]]; then
      run_note="A required step failed. Review failure details and logs."
    fi
  fi

  if [[ ${#executed_steps[@]} -eq 0 ]]; then
    executed_steps_markdown="- No build/test steps were executed."
  else
    executed_steps_markdown=""
    local executed_step
    for executed_step in "${executed_steps[@]}"; do
      executed_steps_markdown+="- ${executed_step}"$'\n'
    done
    executed_steps_markdown=${executed_steps_markdown%$'\n'}
  fi

  write_summary \
    "$start_time_display" \
    "$end_time_display" \
    "$overall_result" \
    "$run_note" \
    "$executed_steps_markdown" \
    "$failed_step" \
    "$failed_log" || true

  write_meta \
    "$start_time_iso" \
    "$end_time_iso" \
    "$duration_seconds" \
    "$overall_result" \
    "$run_note" \
    "$failed_step" \
    "$failed_log" || true

  prune_old_runs 5 || true
}

trap 'finalize_run_artifacts "$?"' EXIT

log_command "$0" "$@"

should_run_pre_commit=false
if [[ "${CI_RUN_ENABLE_PRE_COMMIT:-0}" == "1" || "${CI_RUN_ENABLE_PRE_COMMIT:-}" == "true" ]]; then
  should_run_pre_commit=true
fi

run_step() {
  local step_identifier=$1
  local step_description=$2
  shift 2

  executed_steps+=("$step_description")
  echo "Running ${step_description}."

  if ! run_and_capture "$step_identifier" "$@"; then
    failed_step="$step_description"
    failed_log="$LAST_LOG_PATH"
    overall_result="failure"
    run_note="A required step failed. Review failure details and logs."
    return 1
  fi

  return 0
}

check_log_for_local_warnings() {
  local step_description=$1
  local log_path=$2
  local warning_identifier=$3

  executed_steps+=("$step_description")

  local escaped_repository_root
  escaped_repository_root=$(printf '%s' "$repository_root" | sed 's/[][(){}.^$+*?|\\/]/\\&/g')

  local warning_report_path="$LOG_DIR/${warning_identifier}.log"
  local warning_pattern="^${escaped_repository_root}/(Sources/|Tests/|Example/|Package\\.swift:).*warning:"

  if rg -n --color never "$warning_pattern" "$log_path" >"$warning_report_path"; then
    echo "Local compiler warnings were detected." >&2
    cat "$warning_report_path" >&2
    failed_step="$step_description"
    failed_log="$warning_report_path"
    overall_result="failure"
    run_note="A required step failed. Review failure details and logs."
    return 1
  fi

  rm -f "$warning_report_path"
  return 0
}

if $should_run_pre_commit; then
  run_step \
    "pre_commit" \
    "Run pre-commit hooks" \
    bash "$repository_root/ci_scripts/tasks/pre_commit.sh"
fi

changed_files=$(
  {
    git diff --name-only --cached
    git diff --name-only
    git ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u
)

if [[ -z "$changed_files" ]]; then
  echo "No local changes detected."
  if $should_run_pre_commit; then
    run_note="pre-commit completed. No local changes detected. Build/test steps were skipped."
  else
    run_note="No local changes detected. Build/test steps were skipped."
  fi
  exit 0
fi

needs_swiftlint=false
needs_package_build=false
needs_package_tests=false

if grep -Eq '^(Sources/|Tests/|Example/|Package\.swift$|Package\.resolved$|\.swiftlint\.yml$)' <<<"$changed_files"; then
  needs_swiftlint=true
fi

if grep -Eq '^(Sources/|Example/|Package\.swift$|Package\.resolved$)' <<<"$changed_files"; then
  needs_package_build=true
fi

if grep -Eq '^(Sources/|Tests/|Package\.swift$|Package\.resolved$)' <<<"$changed_files"; then
  needs_package_tests=true
fi

if ! $needs_swiftlint && ! $needs_package_build && ! $needs_package_tests; then
  echo "No package verification inputs changed."
  if $should_run_pre_commit; then
    run_note="pre-commit completed. No changes under Sources/, Tests/, Example/, Package.swift, Package.resolved, or .swiftlint.yml. Build/test steps were skipped."
  else
    run_note="No changes under Sources/, Tests/, Example/, Package.swift, Package.resolved, or .swiftlint.yml. Build/test steps were skipped."
  fi
  exit 0
fi

run_note="Executed required CI steps for MHPlatform based on local changes."

if $needs_package_build || $needs_package_tests; then
  run_step \
    "check_models_directory_consistency" \
    "Check models directory consistency" \
    bash "$repository_root/ci_scripts/tasks/check_models_directory_consistency.sh"
fi

if $needs_swiftlint; then
  if ! command -v swiftlint >/dev/null 2>&1; then
    log_command swiftlint lint --strict --no-cache
    failed_step="Run SwiftLint strict no-cache"
    failed_log="$LOG_DIR/swiftlint_strict.log"
    {
      echo "swiftlint is not installed. Install it and retry."
      echo "Install with: brew install swiftlint"
    } | tee "$failed_log" >&2
    overall_result="failure"
    run_note="A required step failed. Review failure details and logs."
    exit 1
  fi

  run_step \
    "swiftlint_strict" \
    "Run SwiftLint strict no-cache" \
    swiftlint lint --strict --no-cache
fi

if $needs_package_build; then
  run_step \
    "build_app" \
    "Build MHPlatform package and example app" \
    bash "$repository_root/ci_scripts/tasks/build_app.sh"

  check_log_for_local_warnings \
    "Check local compiler warnings in build log" \
    "$LAST_LOG_PATH" \
    "build_app_local_warnings"
fi

if $needs_package_tests; then
  run_step \
    "test_shared_library" \
    "Run Swift package tests" \
    bash "$repository_root/ci_scripts/tasks/test_shared_library.sh"

  check_log_for_local_warnings \
    "Check local compiler warnings in test log" \
    "$LAST_LOG_PATH" \
    "test_shared_library_local_warnings"
fi
