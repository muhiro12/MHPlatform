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
package_cache_directory="$cache_directory/package"
cloned_source_packages_directory="$cache_directory/source_packages"
swiftpm_cache_directory="$cache_directory/swiftpm/cache"
swiftpm_config_directory="$cache_directory/swiftpm/config"

mkdir -p \
  "$work_directory" \
  "$local_home_directory/Library/Caches" \
  "$local_home_directory/Library/Developer" \
  "$local_home_directory/Library/Logs" \
  "$cache_directory" \
  "$clang_module_cache_directory" \
  "$package_cache_directory" \
  "$cloned_source_packages_directory" \
  "$swiftpm_cache_directory" \
  "$swiftpm_config_directory" \
  "$temporary_directory" \
  "$derived_data_path" \
  "$results_directory"

echo "Running swift build for MHPlatform package."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$repository_root/.build" \
swift build

example_project_path="$repository_root/Example/MHPlatformExample.xcodeproj"
if [[ ! -d "$example_project_path" ]]; then
  echo "Example project not found. Skipping MHPlatformExample build."
  exit 0
fi

timestamp=$(date +%s)
macos_result_bundle_path="$results_directory/BuildResults_MHPlatformExample_macOS_${timestamp}.xcresult"
ios_result_bundle_path="$results_directory/BuildResults_MHPlatformExample_iOS_${timestamp}.xcresult"
ios_package_result_bundle_path="$results_directory/BuildResults_MHPlatform_iOS_${timestamp}.xcresult"
watchos_result_bundle_path="$results_directory/BuildResults_MHPlatform_watchOS_${timestamp}.xcresult"

echo "Building MHPlatformExample (macOS)."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$cloned_source_packages_directory" \
xcodebuild \
  -project "$example_project_path" \
  -scheme "MHPlatformExample" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$macos_result_bundle_path" \
  -clonedSourcePackagesDirPath "$cloned_source_packages_directory" \
  -packageCachePath "$package_cache_directory" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "CLANG_MODULE_CACHE_PATH=$clang_module_cache_directory" \
  build

echo "Finished MHPlatformExample macOS build. Result bundle: $macos_result_bundle_path"

echo "Building MHPlatformExample (iOS Simulator)."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$cloned_source_packages_directory" \
xcodebuild \
  -project "$example_project_path" \
  -scheme "MHPlatformExample" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$ios_result_bundle_path" \
  -clonedSourcePackagesDirPath "$cloned_source_packages_directory" \
  -packageCachePath "$package_cache_directory" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "CLANG_MODULE_CACHE_PATH=$clang_module_cache_directory" \
  build

echo "Finished MHPlatformExample iOS Simulator build. Result bundle: $ios_result_bundle_path"

echo "Building MHPlatform package umbrella scheme (iOS Simulator)."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$cloned_source_packages_directory" \
xcodebuild \
  -project "$example_project_path" \
  -scheme "MHPlatform" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$ios_package_result_bundle_path" \
  -clonedSourcePackagesDirPath "$cloned_source_packages_directory" \
  -packageCachePath "$package_cache_directory" \
  "CLANG_MODULE_CACHE_PATH=$clang_module_cache_directory" \
  build

echo "Finished MHPlatform iOS Simulator package build. Result bundle: $ios_package_result_bundle_path"

echo "Building MHPlatform package umbrella scheme (watchOS Simulator)."
HOME="$local_home_directory" \
TMPDIR="$temporary_directory" \
XDG_CACHE_HOME="$cache_directory" \
CLANG_MODULE_CACHE_PATH="$clang_module_cache_directory" \
SWIFTPM_CACHE_PATH="$swiftpm_cache_directory" \
SWIFTPM_CONFIG_PATH="$swiftpm_config_directory" \
PLL_SOURCE_PACKAGES_PATH="$cloned_source_packages_directory" \
xcodebuild \
  -project "$example_project_path" \
  -scheme "MHPlatform" \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath "$derived_data_path" \
  -resultBundlePath "$watchos_result_bundle_path" \
  -clonedSourcePackagesDirPath "$cloned_source_packages_directory" \
  -packageCachePath "$package_cache_directory" \
  "CLANG_MODULE_CACHE_PATH=$clang_module_cache_directory" \
  build

echo "Finished MHPlatform watchOS Simulator package build. Result bundle: $watchos_result_bundle_path"
