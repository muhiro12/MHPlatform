#!/usr/bin/env bash

json_escape() {
  local escaped_value=$1

  escaped_value=${escaped_value//\\/\\\\}
  escaped_value=${escaped_value//\"/\\\"}
  escaped_value=${escaped_value//$'\n'/\\n}
  escaped_value=${escaped_value//$'\r'/\\r}
  escaped_value=${escaped_value//$'\t'/\\t}

  printf '%s' "$escaped_value"
}

create_run_directory() {
  local runs_root=$1

  mkdir -p "$runs_root"
  local absolute_runs_root
  absolute_runs_root=$(cd "$runs_root" && pwd)

  local base_run_id
  base_run_id=$(date +"%Y%m%d-%H%M%S")

  local collision_index=0
  local run_id
  local run_directory
  while :; do
    run_id=$(printf "%s-%04d" "$base_run_id" "$collision_index")
    run_directory="${absolute_runs_root}/${run_id}"
    if [[ ! -e "$run_directory" ]]; then
      break
    fi
    collision_index=$((collision_index + 1))
  done

  mkdir -p "$run_directory/logs" "$run_directory/results" "$run_directory/work"
  : >"$run_directory/commands.txt"

  printf '%s\n' "$run_directory"
}

migrate_legacy_ci_directories() {
  local repository_root=$1
  local runs_root=$2
  local shared_root=$3

  local legacy_runs_directory="$repository_root/.build/ci_runs"
  local legacy_work_directory="$repository_root/.build/work"

  if [[ -d "$legacy_runs_directory" ]]; then
    mkdir -p "$runs_root"
    local legacy_entry
    for legacy_entry in "$legacy_runs_directory"/*; do
      if [[ -e "$legacy_entry" ]]; then
        mv "$legacy_entry" "$runs_root/"
      fi
    done
    rmdir "$legacy_runs_directory" 2>/dev/null || true
  fi

  if [[ -d "$legacy_work_directory" ]]; then
    mkdir -p "$shared_root"
    local legacy_shared_entry
    for legacy_shared_entry in "$legacy_work_directory"/*; do
      if [[ -e "$legacy_shared_entry" ]]; then
        mv "$legacy_shared_entry" "$shared_root/"
      fi
    done
    rmdir "$legacy_work_directory" 2>/dev/null || true
  fi
}

start_run() {
  local repository_root=$1

  CI_ROOT="$repository_root/.build/ci"
  RUNS_ROOT="$CI_ROOT/runs"
  SHARED_ROOT="$CI_ROOT/shared"

  migrate_legacy_ci_directories "$repository_root" "$RUNS_ROOT" "$SHARED_ROOT"

  mkdir -p \
    "$RUNS_ROOT" \
    "$SHARED_ROOT/cache" \
    "$SHARED_ROOT/DerivedData" \
    "$SHARED_ROOT/tmp" \
    "$SHARED_ROOT/home"

  RUN_ROOT=$(create_run_directory "$RUNS_ROOT")
  RUN_ID=$(basename "$RUN_ROOT")

  LOG_DIR="$RUN_ROOT/logs"
  RESULTS_DIR="$RUN_ROOT/results"
  RUN_WORK_DIR="$RUN_ROOT/work"
  COMMANDS_FILE="$RUN_ROOT/commands.txt"
  SUMMARY_PATH="$RUN_ROOT/summary.md"
  META_PATH="$RUN_ROOT/meta.json"
  CACHE_DIR="$SHARED_ROOT/cache"
  DERIVED_DATA_DIR="$SHARED_ROOT/DerivedData"

  export RUN_ID RUN_ROOT RUNS_ROOT SHARED_ROOT LOG_DIR RESULTS_DIR RUN_WORK_DIR
  export COMMANDS_FILE SUMMARY_PATH META_PATH CACHE_DIR DERIVED_DATA_DIR

  export CI_RUN_DIR="$RUN_ROOT"
  export CI_RUN_WORK_DIR="$RUN_WORK_DIR"
  export CI_SHARED_DIR="$SHARED_ROOT"
  export CI_CACHE_DIR="$CACHE_DIR"
  export CI_DERIVED_DATA_DIR="$DERIVED_DATA_DIR"
  export CI_RUN_RESULTS_DIR="$RESULTS_DIR"

  export AI_RUN_WORK_DIR="$RUN_WORK_DIR"
  export AI_RUN_RESULTS_DIR="$RESULTS_DIR"
  export AI_RUN_CACHE_ROOT="$CACHE_DIR"
}

log_command() {
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S %z")

  {
    printf '[%s] ' "$timestamp"
    local token_index=0
    local command_token
    for command_token in "$@"; do
      if [[ $token_index -gt 0 ]]; then
        printf ' '
      fi
      printf '%q' "$command_token"
      token_index=$((token_index + 1))
    done
    printf '\n'
  } >>"$COMMANDS_FILE"
}

run_and_capture() {
  local step_name=$1
  shift

  LAST_LOG_PATH="$LOG_DIR/${step_name}.log"
  log_command "$@"

  set +e
  "$@" 2>&1 | tee "$LAST_LOG_PATH"
  local command_status=${PIPESTATUS[0]}
  set -e

  return "$command_status"
}

write_summary() {
  local started_at=$1
  local ended_at=$2
  local overall_result=$3
  local run_note=$4
  local executed_steps_markdown=$5
  local failed_step=$6
  local failed_log=$7

  {
    printf '# CI Run Summary\n\n'
    printf -- '- Run ID: `%s`\n' "$RUN_ID"
    printf -- '- Start time: `%s`\n' "$started_at"
    printf -- '- End time: `%s`\n' "$ended_at"
    printf -- '- Overall result: **%s**\n\n' "$overall_result"
    printf '## Overview\n\n'
    printf '%s\n\n' "$run_note"
    printf '## Executed Steps\n\n'
    printf '%s\n\n' "$executed_steps_markdown"
    if [[ "$overall_result" == "failure" ]]; then
      printf '## Failure Details\n\n'
      if [[ -n "$failed_step" ]]; then
        printf -- '- Failing step: `%s`\n' "$failed_step"
      else
        printf -- '- Failing step: unavailable\n'
      fi

      if [[ -n "$failed_log" ]]; then
        printf -- '- Log path: `%s`\n\n' "$failed_log"
      else
        printf -- '- Log path: unavailable\n\n'
      fi
    fi
    printf '## Artifact Paths\n\n'
    printf -- '- Commands: `%s`\n' "$COMMANDS_FILE"
    printf -- '- Logs: `%s`\n' "$LOG_DIR"
    printf -- '- Results: `%s`\n' "$RESULTS_DIR"
    printf -- '- Work: `%s`\n' "$RUN_WORK_DIR"
    printf -- '- Shared root: `%s`\n' "$SHARED_ROOT"
  } >"$SUMMARY_PATH"
}

write_meta() {
  local started_at_iso=$1
  local ended_at_iso=$2
  local duration_seconds=$3
  local overall_result=$4
  local run_note=$5
  local failed_step=$6
  local failed_log=$7

  {
    printf '{\n'
    printf '  "run_id": "%s",\n' "$(json_escape "$RUN_ID")"
    printf '  "start_time": "%s",\n' "$(json_escape "$started_at_iso")"
    printf '  "end_time": "%s",\n' "$(json_escape "$ended_at_iso")"
    printf '  "duration_seconds": %s,\n' "$duration_seconds"
    printf '  "result": "%s",\n' "$(json_escape "$overall_result")"
    printf '  "note": "%s",\n' "$(json_escape "$run_note")"
    printf '  "failed_step": "%s",\n' "$(json_escape "$failed_step")"
    printf '  "failed_log": "%s",\n' "$(json_escape "$failed_log")"
    printf '  "commands_file": "%s",\n' "$(json_escape "$COMMANDS_FILE")"
    printf '  "logs_dir": "%s",\n' "$(json_escape "$LOG_DIR")"
    printf '  "results_dir": "%s",\n' "$(json_escape "$RESULTS_DIR")"
    printf '  "work_dir": "%s",\n' "$(json_escape "$RUN_WORK_DIR")"
    printf '  "shared_root": "%s"\n' "$(json_escape "$SHARED_ROOT")"
    printf '}\n'
  } >"$META_PATH"
}

prune_old_runs() {
  local retain_count=$1

  if [[ ! -d "$RUNS_ROOT" ]]; then
    return 0
  fi

  local -a run_directories=()
  local run_directory
  while IFS= read -r run_directory; do
    run_directories+=("$run_directory")
  done < <(find "$RUNS_ROOT" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)

  local total_runs=${#run_directories[@]}
  if [[ $total_runs -le $retain_count ]]; then
    return 0
  fi

  local remove_count=$((total_runs - retain_count))
  local index
  for ((index = 0; index < remove_count; index++)); do
    rm -rf "${run_directories[$index]}"
  done
}
