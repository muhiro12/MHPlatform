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

bash "$repository_root/ci_scripts/tasks/check_environment.sh" --profile rules
CI_SKIP_ENV_CHECK=1 bash "$repository_root/ci_scripts/tasks/lint_swift.sh"
bash "$repository_root/ci_scripts/tasks/check_models_directory_consistency.sh"
bash "$repository_root/ci_scripts/tasks/test_consumer_fixtures.sh"

echo "Repository rules check passed."
