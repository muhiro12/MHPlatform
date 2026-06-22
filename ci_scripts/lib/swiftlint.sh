#!/usr/bin/env bash

ci_swiftlint_shared_directory() {
  local repository_root=$1
  printf '%s\n' "${CI_SHARED_DIR:-$repository_root/.build/ci/shared}"
}

ci_swiftlint_cache_directory() {
  local repository_root=$1
  local shared_directory

  shared_directory=$(ci_swiftlint_shared_directory "$repository_root")
  printf '%s\n' "${CI_CACHE_DIR:-${AI_RUN_CACHE_ROOT:-$shared_directory/cache}}"
}

ci_swiftlint_swiftpm_cache_directory() {
  local repository_root=$1
  local cache_directory

  cache_directory=$(ci_swiftlint_cache_directory "$repository_root")
  printf '%s\n' "$cache_directory/swiftpm/cache"
}

ci_swiftlint_swiftpm_config_directory() {
  local repository_root=$1
  local cache_directory

  cache_directory=$(ci_swiftlint_cache_directory "$repository_root")
  printf '%s\n' "$cache_directory/swiftpm/config"
}

ci_swiftlint_temporary_directory() {
  local repository_root=$1
  local shared_directory

  shared_directory=$(ci_swiftlint_shared_directory "$repository_root")
  printf '%s\n' "$shared_directory/tmp"
}

ci_swiftlint_local_home_directory() {
  local repository_root=$1
  local shared_directory

  shared_directory=$(ci_swiftlint_shared_directory "$repository_root")
  printf '%s\n' "$shared_directory/home"
}

ci_swiftlint_prepare_directories() {
  local repository_root=$1
  local cache_directory
  local swiftpm_cache_directory
  local swiftpm_config_directory
  local temporary_directory
  local local_home_directory

  cache_directory=$(ci_swiftlint_cache_directory "$repository_root")
  swiftpm_cache_directory=$(ci_swiftlint_swiftpm_cache_directory "$repository_root")
  swiftpm_config_directory=$(ci_swiftlint_swiftpm_config_directory "$repository_root")
  temporary_directory=$(ci_swiftlint_temporary_directory "$repository_root")
  local_home_directory=$(ci_swiftlint_local_home_directory "$repository_root")

  mkdir -p \
    "$cache_directory" \
    "$swiftpm_cache_directory" \
    "$swiftpm_config_directory" \
    "$temporary_directory" \
    "$local_home_directory/Library/Caches" \
    "$local_home_directory/Library/Developer" \
    "$local_home_directory/Library/Logs"
}

ci_swiftlint_run() {
  local repository_root=$1
  local mode=$2
  local empty_message
  local start_message
  local finish_message
  local cache_directory
  local swiftpm_cache_directory
  local swiftpm_config_directory
  local temporary_directory
  local local_home_directory
  local -a swiftlint_arguments=()
  local -a swift_files=()

  case "$mode" in
    format)
      empty_message="No Swift files found to format."
      start_message="Formatting Swift files with repository-managed SwiftLint..."
      finish_message="Finished formatting Swift files."
      ;;
    lint)
      empty_message="No Swift files found to lint."
      start_message="Linting Swift files with repository-managed SwiftLint..."
      finish_message="Finished linting Swift files."
      ;;
    *)
      echo "Unknown SwiftLint mode: $mode" >&2
      return 2
      ;;
  esac

  while IFS= read -r -d '' file; do
    if [[ "$file" == "Package.swift" ]]; then
      continue
    fi
    swift_files+=("$file")
  done < <(
    git ls-files -z -- '*.swift'
    git ls-files -z --others --exclude-standard -- '*.swift'
  )

  if [[ ${#swift_files[@]} -eq 0 ]]; then
    echo "$empty_message"
    return 0
  fi

  ci_swiftlint_prepare_directories "$repository_root"

  cache_directory=$(ci_swiftlint_cache_directory "$repository_root")
  swiftpm_cache_directory=$(ci_swiftlint_swiftpm_cache_directory "$repository_root")
  swiftpm_config_directory=$(ci_swiftlint_swiftpm_config_directory "$repository_root")
  temporary_directory=$(ci_swiftlint_temporary_directory "$repository_root")
  local_home_directory=$(ci_swiftlint_local_home_directory "$repository_root")

  case "$mode" in
    format)
      swiftlint_arguments=(lint --quiet --no-cache --fix --format "${swift_files[@]}")
      ;;
    lint)
      swiftlint_arguments=(lint --quiet --no-cache --strict "${swift_files[@]}")
      ;;
  esac

  echo "$start_message"
  HOME="$local_home_directory" \
    TMPDIR="$temporary_directory" \
    XDG_CACHE_HOME="$cache_directory" \
    SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
    SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
    swift package plugin \
      --allow-writing-to-package-directory \
      --package swiftlintplugins \
      swiftlint \
      -- "${swiftlint_arguments[@]}"
  echo "$finish_message"
}
