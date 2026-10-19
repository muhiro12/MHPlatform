#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash ci_scripts/tasks/build_remote_config_validator.sh <output-directory>" >&2
  exit 2
fi

script_directory=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_directory/../.." && pwd)
mkdir -p "$1"
output_directory=$(cd "$1" && pwd)
sdk_path=$(xcrun --sdk macosx --show-sdk-path)
target="$(uname -m)-apple-macosx15.0"
compiler_options=(-sdk "$sdk_path" -target "$target" -swift-version 6 -warnings-as-errors -parse-as-library)

# Compile only the two owning modules; publisher tooling needs no app/advertising dependencies.
xcrun swiftc "${compiler_options[@]}" -emit-module -emit-library \
  -module-name MHRemoteConfig -emit-module-path "$output_directory/MHRemoteConfig.swiftmodule" \
  "$repository_root"/Sources/MHRemoteConfig/*.swift -o "$output_directory/libMHRemoteConfig.dylib"
xcrun swiftc "${compiler_options[@]}" -emit-module -emit-library \
  -module-name MHRemoteUpdate -emit-module-path "$output_directory/MHRemoteUpdate.swiftmodule" \
  -I "$output_directory" -L "$output_directory" -lMHRemoteConfig \
  -Xlinker -rpath -Xlinker @loader_path \
  "$repository_root"/Sources/MHRemoteUpdate/*.swift -o "$output_directory/libMHRemoteUpdate.dylib"
xcrun swiftc "${compiler_options[@]}" -I "$output_directory" -L "$output_directory" \
  -lMHRemoteConfig -lMHRemoteUpdate -Xlinker -rpath -Xlinker @executable_path \
  "$repository_root/Tools/RemoteConfigValidator.swift" -o "$output_directory/mh-validate-remote-config"
