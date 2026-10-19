#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "This script does not accept arguments." >&2
  exit 2
fi

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/../.." && pwd)
output_directory="$repository_root/.build/ci/remote-config-validator"
bash "$script_directory/build_remote_config_validator.sh" "$output_directory"
python3 "$repository_root/ci_scripts/tests/test_remote_config_validator.py" \
  "$output_directory/mh-validate-remote-config"
