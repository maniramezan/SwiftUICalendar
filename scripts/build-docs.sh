#!/usr/bin/env bash

set -euo pipefail

# Forward SwiftPM flags, such as --cache-path, to support isolated build environments.
symbol_graph_log="$(mktemp)"
trap 'rm -f "${symbol_graph_log}"' EXIT
swift package "$@" dump-symbol-graph | tee "${symbol_graph_log}"
symbol_graph_path="$(sed -n 's/^Files written to //p' "${symbol_graph_log}" | tail -n 1)"
if [[ -z "${symbol_graph_path}" ]]; then
  echo "error: SwiftPM did not produce symbol graphs" >&2
  exit 1
fi

symbol_graph_filter_dir="$(mktemp -d)"
trap 'rm -f "${symbol_graph_log}"; rm -rf "${symbol_graph_filter_dir}"' EXIT
cp "${symbol_graph_path}"/SwiftUICalendar.symbols.json "${symbol_graph_filter_dir}/"
cp "${symbol_graph_path}"/SwiftUICalendar@*.symbols.json "${symbol_graph_filter_dir}/" 2>/dev/null || true

output_path=".build/docs"
hosting_args=()
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  hosting_args=(--hosting-base-path "/${GITHUB_REPOSITORY#*/}")
fi

xcrun docc convert Sources/SwiftUICalendar/SwiftUICalendar.docc \
  --additional-symbol-graph-dir "${symbol_graph_filter_dir}" \
  --output-path "${output_path}" \
  --fallback-display-name SwiftUICalendar \
  --fallback-bundle-identifier com.maniramezan.SwiftUICalendar \
  --warnings-as-errors \
  --transform-for-static-hosting \
  ${hosting_args[@]+"${hosting_args[@]}"}

cat > "${output_path}/index.html" <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/swiftuicalendar">
    <title>SwiftUICalendar Documentation</title>
  </head>
  <body>
    <p><a href="documentation/swiftuicalendar">SwiftUICalendar documentation</a></p>
  </body>
</html>
HTML
