#!/usr/bin/env bash
set -euo pipefail

argument_count=$#
if [[ $argument_count -ne 0 ]]; then
  echo "This script does not accept arguments." >&2
  exit 2
fi

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/.." && pwd)
cd "$repository_root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must run inside a git repository." >&2
  exit 1
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
  exit 0
fi

needs_required_builds=false

if grep -Eq '^(Sources/|Tests/|Example/|Package\.swift$|\.swiftlint\.yml$|\.pre-commit-config\.yaml$|ci_scripts/)' <<<"$changed_files"; then
  needs_required_builds=true
fi

if ! $needs_required_builds; then
  echo "No changes that require MHKit builds/tests."
  exit 0
fi

echo "Running swift test."
swift test

echo "Building MHKitExample (macOS)."
xcodebuild -project Example/MHKitExample.xcodeproj -scheme MHKitExample -destination 'generic/platform=macOS' build

echo "Running SwiftLint strict no-cache."
swiftlint lint --strict --no-cache
