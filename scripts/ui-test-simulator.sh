#!/usr/bin/env bash

# Boots the UI-test simulator ahead of xcodebuild and runs a test plan against it.
#
#   ui-test-simulator.sh boot <device name>       Boot the newest iOS runtime's <device name> and
#                                                print its UDID.
#   ui-test-simulator.sh wait <udid>              Block until the simulator has finished booting
#                                                and its background work has quieted down.
#   ui-test-simulator.sh test <udid> <plan> <result bundle> [xcodebuild flags...]
#                                                Run <plan>, rebooting and retrying once if the
#                                                test runner never connects.
#
# A cold simulator reports "Booted" seconds after `simctl boot`, long before first-boot setup ends.
# Left to xcodebuild, the test runner is launched suspended into that churn, and xcodebuild can fail
# to reach the simulator's service hub to resume it, so no test runs and the plan fails after the
# 300-second startup timer. Booting first and waiting on `bootstatus` avoids most of that; the retry
# covers the rest.
#
# `bootstatus` returns while the simulator is still indexing, rendering posters, and compiling
# shaders. On a 3-CPU runner that work starves the app under test: run 38411339964 spent 12 to 55
# seconds per accessibility query and timed out a test that passes in under a minute. So `wait`
# also holds until the simulator's own processes go quiet.

set -euo pipefail

hang_marker="hung before establishing connection"
# Combined CPU of the simulator's processes, in percent of one core, that counts as quiet. A settled
# CI simulator idles at 35-40%, mostly `diagnosticd` (run 38428942312).
quiet_cpu="${SIMULATOR_QUIET_CPU:-50}"
quiet_timeout="${SIMULATOR_QUIET_TIMEOUT:-600}"
quiet_checks=3
quiet_interval=5

# Prints "<cpu> <process>" for the simulator's processes, busiest first. They run from the
# simulator runtime's root or, for installed apps, from the device's own directory.
simulator_processes() {
  # `comm` is the full executable path, which can contain spaces ("iOS 27.0.simruntime").
  ps -axo %cpu=,comm= | awk -v device="CoreSimulator/Devices/$1/" '
    index($0, "CoreSimulator/Profiles/Runtimes/") || index($0, device) {
      name = $0; sub(/.*\//, "", name); print $1, name
    }' | sort -rn
}

wait_for_quiet() {
  local udid="$1" started=$SECONDS quiet=0 total
  while ((SECONDS - started < quiet_timeout)); do
    total="$(simulator_processes "${udid}" | awk '{ sum += $1 } END { printf "%d", sum }')"
    if ((total <= quiet_cpu)); then
      quiet=$((quiet + 1))
      if ((quiet >= quiet_checks)); then
        echo "Simulator went quiet (${total}% CPU) after $((SECONDS - started))s"
        return 0
      fi
    else
      quiet=0
      if (((SECONDS - started) % 30 < quiet_interval)); then
        echo "Simulator still busy at ${total}% CPU; busiest processes:"
        simulator_processes "${udid}" | head -5 | sed 's/^/  /'
      fi
    fi
    sleep "${quiet_interval}"
  done
  # Testing a busy simulator is slower, not wrong, so carry on rather than fail the job.
  echo "::warning::The simulator was still busy after ${quiet_timeout}s; testing anyway"
  simulator_processes "${udid}" | head -5 | sed 's/^/  /'
}

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
  wait_for_quiet "${udid}"
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
