#!/usr/bin/env bash

set -euo pipefail

minimum_swift_version="${MINIMUM_SWIFT_VERSION:-6.2}"

swift_version_major_minor() {
  swift --version | ruby -ne 'if $_ =~ /Swift version (\d+\.\d+)/; puts $1; exit; end'
}

version_at_least() {
  ruby -e 'exit(Gem::Version.new(ARGV[0]) >= Gem::Version.new(ARGV[1]) ? 0 : 1)' "$1" "$2"
}

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
