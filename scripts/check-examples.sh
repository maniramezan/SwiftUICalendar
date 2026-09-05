#!/usr/bin/env bash
set -euo pipefail

swift build "$@" -c debug
binary_path="$(swift build "$@" --show-bin-path)"
compiler_args=()
for option in "$@"; do
  if [[ "${option}" == "--disable-sandbox" ]]; then
    compiler_args=(-disable-sandbox)
  fi
done
xcrun swiftc ${compiler_args[@]+"${compiler_args[@]}"} -typecheck Examples/DocumentationExamples.swift \
  -swift-version 6 -target "$(uname -m)-apple-macosx15.0" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -I "${binary_path}" -I "${binary_path}/Modules" \
  -F "${binary_path}/PackageFrameworks"
