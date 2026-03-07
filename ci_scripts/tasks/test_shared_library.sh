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

shared_directory="${CI_SHARED_DIR:-$repository_root/.build/ci/shared}"
cache_directory="${CI_CACHE_DIR:-$shared_directory/cache}"
temporary_directory="$shared_directory/tmp"
local_home_directory="$shared_directory/home"
package_cache_directory="$cache_directory/package"
swiftpm_cache_directory="$cache_directory/swiftpm/cache"
swiftpm_config_directory="$cache_directory/swiftpm/config"

mkdir -p \
  "$cache_directory" \
  "$package_cache_directory" \
  "$swiftpm_cache_directory" \
  "$swiftpm_config_directory" \
  "$temporary_directory" \
  "$local_home_directory/Library/Caches"

echo "Running swift test for MHPlatform package."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$repository_root/.build" \
swift test
