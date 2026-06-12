#!/usr/bin/env bash

set -euo pipefail

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

# The DocC JS app does not auto-navigate from the site root, so a bare visit to the
# GitHub Pages root would show "page not found". Write a meta-refresh redirect to the
# documentation landing page.
cat > "${output_path}/index.html" <<'EOF'
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/swiftuicalendar">
    <link rel="canonical" href="documentation/swiftuicalendar">
    <title>SwiftUICalendar Documentation</title>
  </head>
  <body>
    <p>Redirecting to <a href="documentation/swiftuicalendar">SwiftUICalendar documentation</a>…</p>
  </body>
</html>
EOF
