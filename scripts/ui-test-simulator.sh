#!/usr/bin/env bash

# Own one fresh simulator per job; the runner's existing devices and their data are untouched.
# Xcode chooses parallel workers from the test plans and reuses the build-for-testing products.
#
#   ui-test-simulator.sh create <device name>     Print a fresh device's UDID on the newest runtime.
#   ui-test-simulator.sh wait <udid>              Boot and wait for first-boot setup to finish.
#   ui-test-simulator.sh test <udid> <plan> <result bundle> [xcodebuild flags...]
#   ui-test-simulator.sh delete <udid>            Shut down and remove the owned device.

set -euo pipefail

create_device() {
  xcrun simctl list devices available -j | ruby -rjson -e '
    name = ARGV.fetch(0)
    runtimes = JSON.parse($stdin.read).fetch("devices").select { |runtime, _| runtime.include?("iOS") }
    newest = runtimes.max_by { |runtime, _| Gem::Version.new(runtime[/iOS-([\d-]+)/, 1].tr("-", ".")) }
    device = newest&.last&.find { |candidate| candidate["name"] == name }
    abort "error: no available #{name} simulator on #{newest&.first || "any iOS runtime"}" unless device
    # Create instead of clone: cloning would also copy application data from the template.
    exec "xcrun", "simctl", "create", "SwiftUICalendar CI #{Process.pid}",
      device.fetch("deviceTypeIdentifier"), newest.first
  ' "$1"
}

case "${1:-}" in
  create)
    create_device "$2"
    ;;
  wait)
    # bootstatus waits for data migration and setup, not just the "Booted" state. No CPU-idle
    # heuristic: system background services can remain busy even when the device is usable.
    xcrun simctl bootstatus "$2" -b
    ;;
  test)
    udid="$2" plan="$3" result="$4"
    shift 4
    mkdir -p "$(dirname "${result}")"
    xcodebuild test-without-building -testProductsPath .build/SampleUITests.xctestproducts \
      -testPlan "${plan}" -destination "id=${udid}" "$@" -resultBundlePath "${result}"
    ;;
  delete)
    # Xcode may already have shut down the device after testing.
    xcrun simctl shutdown "$2" 2>/dev/null || true
    xcrun simctl delete "$2"
    ;;
  *)
    echo "usage: $0 create <device name> | wait <udid> | test <udid> <plan> <result> [flags...] | delete <udid>" >&2
    exit 64
    ;;
esac
