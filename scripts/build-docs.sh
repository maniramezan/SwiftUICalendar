#!/usr/bin/env bash

set -euo pipefail

: "${DEVELOPER_DIR:?DEVELOPER_DIR must be set to an Xcode developer directory}"

derived_data_path=".build/DerivedData"
archive_path="${derived_data_path}/Build/Products/Debug/SwiftUICalendar.doccarchive"
output_path=".build/docs"

hosting_base_path=""
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  repo_name="${GITHUB_REPOSITORY#*/}"
  hosting_base_path="/${repo_name}"
fi

xcodebuild \
  -scheme SwiftUICalendar \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${derived_data_path}" \
  docbuild

rm -rf "${output_path}"

if [[ -n "${hosting_base_path}" ]]; then
  xcrun docc process-archive transform-for-static-hosting \
    "${archive_path}" \
    --output-path "${output_path}" \
    --hosting-base-path "${hosting_base_path}"
else
  xcrun docc process-archive transform-for-static-hosting \
    "${archive_path}" \
    --output-path "${output_path}"
fi
