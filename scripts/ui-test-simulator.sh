#!/usr/bin/env bash

# Own one fresh simulator per job; the runner's existing devices and their data are untouched.
# The tests run on that one device, booted and settled before xcodebuild starts, and reuse the
# build-for-testing products.
#
# Parallel testing is off on purpose. For a parallelizable plan Xcode creates and cold-boots its own
# "Clone N" devices, so warming the owned device does nothing for the clones that run the tests. On
# the 3-CPU runner the first test on each cold clone then spent 90 seconds to 8 minutes in first-boot
# churn (including a 120-second wait for the instruments lockdown service) and tripped the 180-second
# test allowance, a different test each run. Once settled, every test takes 15 to 80 seconds. The
# matrix already spreads the plans across runners, so one worker per runner costs little.
#
#   ui-test-simulator.sh create <device name>     Print a fresh device's UDID on the newest runtime.
#   ui-test-simulator.sh prepare <udid>           Boot and wait for first-boot setup to finish.
#   ui-test-simulator.sh test <udid> <plan> <result bundle> [xcodebuild flags...]
#   ui-test-simulator.sh delete <udid>            Shut down and remove the owned device.
#
# Set UI_TEST_CONFIGURATION to select a configuration, and UI_TEST_SUITES to a newline-delimited
# list of test classes. An empty suite list runs the complete plan.

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
  prepare)
    # bootstatus waits for data migration and setup, not just the "Booted" state. The device stays
    # booted: it is the one the tests run on.
    xcrun simctl bootstatus "$2" -b
    ;;
  test)
    udid="$2" plan="$3" result="$4"
    shift 4
    mkdir -p "$(dirname "${result}")"
    if [[ -n "${UI_TEST_CONFIGURATION:-}" ]]; then
      set -- "$@" -only-test-configuration "$UI_TEST_CONFIGURATION"
    fi
    while IFS= read -r suite; do
      [[ -z "$suite" ]] && continue
      set -- "$@" "-only-testing:SwiftUICalendarSampleUITests/$suite"
    done <<< "${UI_TEST_SUITES:-}"
    # Unlike xcodebuild's buffered console summary, this records test progress as it happens.
    stream="${result%.xcresult}.events.jsonl"
    : > "$stream"
    xcodebuild test-without-building -testProductsPath .build/SampleUITests.xctestproducts \
      -testPlan "${plan}" -destination "id=${udid}" -parallel-testing-enabled NO "$@" \
      -resultBundlePath "${result}" \
      -resultStreamPath "$stream"
    ;;
  delete)
    # Xcode may already have shut down the device after testing.
    xcrun simctl shutdown "$2" 2>/dev/null || true
    xcrun simctl delete "$2"
    ;;
  *)
    echo "usage: $0 create <device name> | prepare <udid> | test <udid> <plan> <result> [flags...] | delete <udid>" >&2
    exit 64
    ;;
esac
