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
work_directory="${CI_RUN_WORK_DIR:-${AI_RUN_WORK_DIR:-$shared_directory/work}}"
cache_directory="${CI_CACHE_DIR:-${AI_RUN_CACHE_ROOT:-$shared_directory/cache}}"
derived_data_path="${CI_DERIVED_DATA_DIR:-$shared_directory/DerivedData}"
results_directory="${CI_RUN_RESULTS_DIR:-${AI_RUN_RESULTS_DIR:-$work_directory/results}}"

local_home_directory="$shared_directory/home"
temporary_directory="$shared_directory/tmp"
clang_module_cache_directory="$cache_directory/clang/ModuleCache"

mkdir -p \
  "$work_directory" \
  "$local_home_directory/Library/Caches" \
  "$local_home_directory/Library/Developer" \
  "$local_home_directory/Library/Logs" \
  "$cache_directory" \
  "$clang_module_cache_directory" \
  "$temporary_directory" \
  "$derived_data_path" \
  "$results_directory"

echo "Running swift build for MHKit package."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
swift build

example_project_path="$repository_root/Example/MHKitExample.xcodeproj"
if [[ ! -d "$example_project_path" ]]; then
  echo "Example project not found. Skipping MHKitExample build."
  exit 0
fi

timestamp=$(date +%s)
result_bundle_path="$results_directory/BuildResults_MHKitExample_${timestamp}.xcresult"

echo "Building MHKitExample (macOS)."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
xcodebuild \
  -project "$example_project_path" \
  -scheme "MHKitExample" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$result_bundle_path" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "CLANG_MODULE_CACHE_PATH=$clang_module_cache_directory" \
  build

echo "Finished MHKitExample build. Result bundle: $result_bundle_path"
