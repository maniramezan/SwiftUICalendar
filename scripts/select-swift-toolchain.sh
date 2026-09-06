#!/usr/bin/env bash

set -euo pipefail

minimum_swift_version="${MINIMUM_SWIFT_VERSION:-6.4}"

swift_version_major_minor() {
  swift --version | ruby -ne 'if $_ =~ /Swift version (\d+\.\d+)/; puts $1; exit; end'
}

version_at_least() {
  ruby -e 'exit(Gem::Version.new(ARGV[0]) >= Gem::Version.new(ARGV[1]) ? 0 : 1)' "$1" "$2"
}

# CI pins a toolchain so SDK selection cannot change when the runner default changes.
if [[ -n "${XCODE_VERSION:-}" ]]; then
  developer_path="/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer"
  if [[ ! -d "${developer_path}" ]]; then
    echo "error: required Xcode ${XCODE_VERSION} is not installed" >&2
    exit 1
  fi
  sudo xcode-select -s "${developer_path}"
fi

current_version="$(swift_version_major_minor)"
if [[ -n "${current_version}" ]] && version_at_least "${current_version}" "${minimum_swift_version}"; then
  swift --version
  exit 0
fi

for xcode_app in /Applications/Xcode*.app; do
  [[ -d "${xcode_app}/Contents/Developer" ]] || continue
  sudo xcode-select -s "${xcode_app}/Contents/Developer"

  current_version="$(swift_version_major_minor)"
  if [[ -n "${current_version}" ]] && version_at_least "${current_version}" "${minimum_swift_version}"; then
    swift --version
    exit 0
  fi
done

echo "error: Swift ${minimum_swift_version}+ is required." >&2
echo "Installed Xcode toolchains:" >&2
ls -1 /Applications/Xcode*.app 2>/dev/null >&2 || true
exit 1
