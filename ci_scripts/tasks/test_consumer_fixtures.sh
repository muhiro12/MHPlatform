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
cache_directory="${CI_CACHE_DIR:-${AI_RUN_CACHE_ROOT:-$shared_directory/cache}}"
temporary_directory="$shared_directory/tmp"
local_home_directory="$shared_directory/home"
clang_module_cache_directory="$cache_directory/clang/ModuleCache"
swiftpm_cache_directory="$cache_directory/swiftpm/cache"
swiftpm_config_directory="$cache_directory/swiftpm/config"
fixtures_root="$repository_root/Fixtures/Consumers"
shared_scratch_directory="$repository_root/.build"

mkdir -p \
  "$cache_directory" \
  "$temporary_directory" \
  "$local_home_directory/Library/Caches" \
  "$clang_module_cache_directory" \
  "$swiftpm_cache_directory" \
  "$swiftpm_config_directory" \
  "$shared_scratch_directory"

fixtures=(
  "SharedLibraryConsumer"
  "RuntimeOnlyConsumer"
  "DefaultRuntimeConsumer"
  "OptionalShellConsumer"
)

echo "Testing MHPlatform consumer fixtures."

for fixture_name in "${fixtures[@]}"; do
  fixture_directory="$fixtures_root/$fixture_name"

  if [[ ! -d "$fixture_directory" ]]; then
    echo "Missing consumer fixture: $fixture_directory" >&2
    exit 1
  fi

  echo "Testing consumer fixture: $fixture_name"
  HOME="$local_home_directory" \
  TMPDIR="$temporary_directory" \
  XDG_CACHE_HOME="$cache_directory" \
  CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
  SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
  SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
  PLL_SOURCE_PACKAGES_PATH="$repository_root/.build" \
  swift test \
    --disable-sandbox \
    --disable-automatic-resolution \
    --package-path "$fixture_directory" \
    --scratch-path "$shared_scratch_directory"
done
