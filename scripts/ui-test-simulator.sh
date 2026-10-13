#!/usr/bin/env bash

# Boots the UI-test simulator ahead of xcodebuild and runs a test plan against it.
#
#   ui-test-simulator.sh boot <device name>       Boot the newest iOS runtime's <device name> and
#                                                print its UDID.
#   ui-test-simulator.sh wait <udid>              Block until the simulator has finished booting.
#   ui-test-simulator.sh test <udid> <plan> <result bundle> [xcodebuild flags...]
#                                                Run <plan>, rebooting and retrying once if the
#                                                test runner never connects.
#
# A cold simulator reports "Booted" seconds after `simctl boot`, long before first-boot setup ends.
# Left to xcodebuild, the test runner is launched suspended into that churn, and xcodebuild can fail
# to reach the simulator's service hub to resume it, so no test runs and the plan fails after the
# 300-second startup timer. Booting during the build and waiting on `bootstatus` avoids most of
# that; the retry covers the rest.

set -euo pipefail

hang_marker="hung before establishing connection"

resolve_udid() {
  xcrun simctl list devices available -j | ruby -rjson -e '
    name = ARGV.fetch(0)
    runtimes = JSON.parse($stdin.read).fetch("devices").select { |runtime, _| runtime.include?("iOS") }
    newest = runtimes.max_by { |runtime, _| Gem::Version.new(runtime[/iOS-([\d-]+)/, 1].tr("-", ".")) }
    device = newest&.last&.find { |candidate| candidate["name"] == name }
    abort "error: no available #{name} simulator on #{newest&.first || "any iOS runtime"}" unless device
    puts device.fetch("udid")
  ' "$1"
}

wait_for_boot() {
  local udid="$1"
  local started=$SECONDS
  # `-b` boots the device if it is not already booting, then waits for data migration and the
  # rest of first-boot setup, not just the "Booted" state.
  xcrun simctl bootstatus "${udid}" -b
  echo "Simulator ${udid} finished booting after $((SECONDS - started))s of waiting"
}

run_plan() {
  local udid="$1" plan="$2" result="$3" log
  shift 3
  log="$(mktemp)"
  rm -rf "${result}"
  set +e
  xcodebuild test-without-building -testProductsPath .build/SampleUITests.xctestproducts \
    -testPlan "${plan}" -destination "id=${udid}" "$@" -resultBundlePath "${result}" 2>&1 \
    | tee "${log}"
  local status=${PIPESTATUS[0]}
  set -e
  if [[ ${status} -ne 0 ]] && grep -q "${hang_marker}" "${log}"; then
    status=75
  fi
  rm -f "${log}"
  return "${status}"
}

case "${1:-}" in
  boot)
    udid="$(resolve_udid "$2")"
    xcrun simctl boot "${udid}" 2>/dev/null || true
    echo "${udid}"
    ;;
  wait)
    wait_for_boot "$2"
    ;;
  test)
    udid="$2" plan="$3" result="$4"
    shift 4
    status=0
    run_plan "${udid}" "${plan}" "${result}" "$@" || status=$?
    if [[ ${status} -eq 75 ]]; then
      echo "::warning::The ${plan} test runner never connected; rebooting the simulator and retrying once"
      # Keep the hung attempt's spindump and session log for diagnosis.
      mv "${result}" "${result%.xcresult}-hung.xcresult" 2>/dev/null || true
      xcrun simctl shutdown "${udid}" || true
      wait_for_boot "${udid}"
      status=0
      run_plan "${udid}" "${plan}" "${result}" "$@" || status=$?
    fi
    exit "${status}"
    ;;
  *)
    echo "usage: $0 boot <device name> | wait <udid> | test <udid> <plan> <result> [flags...]" >&2
    exit 64
    ;;
esac
