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

echo "Running MHPlatform retained repository rule checks."

bash "$repository_root/ci_scripts/tasks/check_models_directory_consistency.sh"
bash "$repository_root/ci_scripts/tasks/test_consumer_fixtures.sh"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint is not installed. Install it and retry." >&2
  echo "Install with: brew install swiftlint" >&2
  exit 1
fi

swiftlint lint --strict --no-cache

echo "Repository rules check passed."
