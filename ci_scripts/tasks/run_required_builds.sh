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
run_note="Executed required build and test steps for MHKit."
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
    if [[ "$run_note" == "Executed required build and test steps for MHKit." ]]; then
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

run_step \
  "check_models_directory_consistency" \
  "Check models directory consistency" \
  bash "$repository_root/ci_scripts/tasks/check_models_directory_consistency.sh"

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

run_step \
  "build_app" \
  "Build MHKit package and example app" \
  bash "$repository_root/ci_scripts/tasks/build_app.sh"

run_step \
  "test_shared_library" \
  "Run Swift package tests" \
  bash "$repository_root/ci_scripts/tasks/test_shared_library.sh"
