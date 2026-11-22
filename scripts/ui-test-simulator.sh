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
#   ui-test-simulator.sh create <device name>     Print a fresh device's UDID on the newest supported runtime.
#   ui-test-simulator.sh prepare <udid>           Boot, then wait for first-boot setup and its
#                                                background work to finish.
#   ui-test-simulator.sh test <udid> <plan> <result bundle> [xcodebuild flags...]
#   ui-test-simulator.sh delete <udid>            Shut down and remove the owned device.
#
# Set UI_TEST_CONFIGURATION to select a configuration, and UI_TEST_SUITES to a newline-delimited
# list of test classes. An empty suite list runs the complete plan.
#
# `test` reruns the tests that failed, once, in a second xcodebuild session that writes
# <result>-retry.xcresult. xcodebuild's own -retry-tests-on-failure cannot do this job: it reruns a
# test whose assertion failed, but not one that ran out its time allowance, because the timeout
# kills the test runner and the restarted runner moves on to the next test. On the CI runners about
# one app launch in forty never reports back to XCTest (the app is up and idle, the launch call
# never returns), which times out whichever test made it. A real failure fails both sessions.

set -euo pipefail

create_device() {
  xcrun simctl list runtimes -j | ruby -rjson -e '
    name = ARGV.fetch(0)
    runtimes = JSON.parse($stdin.read).fetch("runtimes").select do |runtime|
      runtime["isAvailable"] && runtime.fetch("identifier").start_with?("com.apple.CoreSimulator.SimRuntime.iOS-")
    end
    candidates = runtimes.map do |runtime|
      device_type = runtime.fetch("supportedDeviceTypes").find { |candidate| candidate["name"] == name }
      [runtime, device_type] if device_type
    end.compact
    newest = candidates.max_by { |runtime, _| Gem::Version.new(runtime.fetch("version")) }
    abort "error: no available iOS runtime supports #{name}" unless newest
    runtime, device_type = newest
    exec "xcrun", "simctl", "create", "SwiftUICalendar CI #{Process.pid}",
      device_type.fetch("identifier"), runtime.fetch("identifier")
  ' "$1"
}

UI_TEST_TARGET="SwiftUICalendarSampleUITests"

# `bootstatus` reports a terminal status minutes before the simulator stops launching its own
# services. On the 3-CPU runner run 44969416895 found 153 runnable simulator processes six minutes
# after boot, still spawning; `top -l 1` took 5.5 minutes, `xcodebuild` printed nothing for 5 to 8
# minutes, and three iPad package jobs were cancelled by GitHub in that stall with no reason given.
# So `prepare` also holds until the simulator's processes stay under `quiet_cpu` percent of one
# core. A settled CI simulator idles at 35-40%, mostly `diagnosticd` (run 38428942312).
quiet_cpu="${SIMULATOR_QUIET_CPU:-50}"
quiet_timeout="${SIMULATOR_QUIET_TIMEOUT:-600}"
quiet_checks=3
quiet_interval="${SIMULATOR_QUIET_INTERVAL:-5}"

# Prints "<cpu> <process>" for the device's processes, busiest first: its `launchd_sim` and the
# services that launchd starts. Every booted simulator runs from the same runtime root, so the
# device is told apart by its own launchd, whose arguments name the device's directory.
simulator_processes() {
  local root
  root="$(pgrep -f "CoreSimulator/Devices/$1/data/var/run/launchd_bootstrap.plist" | head -1 || true)"
  [[ -n "$root" ]] || return 0
  # `comm` is the full executable path, which can contain spaces ("iOS 27.2.simruntime").
  ps -axo pid=,ppid=,%cpu=,comm= | awk -v root="$root" '
    $1 == root || $2 == root {
      cpu = $3; name = $0; sub(/.*\//, "", name); print cpu, name
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
        echo "Simulator still busy at ${total}% CPU after $((SECONDS - started))s; busiest processes:"
        simulator_processes "${udid}" | head -5 | sed 's/^/  /'
      fi
    fi
    sleep "${quiet_interval}"
  done
  # Testing a busy simulator is slower, not wrong, so carry on rather than fail the job.
  echo "::warning::The simulator was still busy after ${quiet_timeout}s; testing anyway"
  simulator_processes "${udid}" | head -5 | sed 's/^/  /'
}

# One xcodebuild session on the owned device: run_tests <result bundle> [xcodebuild flags...]
run_tests() {
  local result="$1"
  shift
  # Unlike xcodebuild's buffered console summary, this records test progress as it happens.
  local stream="${result%.xcresult}.events.jsonl"
  : > "$stream"
  xcodebuild test-without-building -testProductsPath .build/SampleUITests.xctestproducts \
    -testPlan "${plan}" -destination "id=${udid}" -parallel-testing-enabled NO "$@" \
    -resultBundlePath "${result}" \
    -resultStreamPath "$stream"
}

# Print an -only-testing filter for every test case the result bundle records as failed.
failed_test_filters() {
  [[ -d "$1" ]] || return 0
  xcrun xcresulttool get test-results tests --path "$1" --compact 2>/dev/null | ruby -rjson -e '
    target = ARGV.fetch(0)
    failed = []
    walk = lambda do |node|
      if node["nodeType"] == "Test Case" && node["result"] == "Failed" && node["nodeIdentifier"]
        failed << node["nodeIdentifier"].sub(/\(\)\z/, "")
      end
      (node["children"] || []).each(&walk)
    end
    begin
      (JSON.parse($stdin.read)["testNodes"] || []).each(&walk)
    rescue JSON::ParserError
      exit 0
    end
    failed.uniq.each { |identifier| puts "-only-testing:#{target}/#{identifier}" }
  ' "$UI_TEST_TARGET" || true
}

case "${1:-}" in
  create)
    create_device "$2"
    ;;
  prepare)
    # bootstatus waits for data migration and setup, not just the "Booted" state. The device stays
    # booted: it is the one the tests run on. It is ready once bootstatus reports a terminal status,
    # but the command can linger long after that: 1.5 to 3 minutes on the CI runners, and once past
    # the 6-minute step limit. So stop at the terminal status. A bootstatus that exits without one
    # (a failed boot) fails the job with its own exit status.
    #
    # The lingering command is killed outright and never waited for, and nothing else here talks to
    # CoreSimulator: in three jobs of one run the step printed the terminal status and then sat
    # silent for four minutes, in the wait for a terminated bootstatus or the simctl call after it.
    log="$(mktemp)"
    xcrun simctl bootstatus "$2" -b >"$log" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null && ! grep -q "isTerminal=YES" "$log"; do
      sleep 1
    done
    cat "$log"
    if grep -q "isTerminal=YES" "$log"; then
      rm -f "$log"
      disown "$pid" 2>/dev/null || true
      pkill -KILL -P "$pid" 2>/dev/null || true
      kill -KILL "$pid" 2>/dev/null || true
    else
      rm -f "$log"
      wait "$pid"
    fi
    wait_for_quiet "$2"
    ;;
  test)
    udid="$2" plan="$3" result="$4"
    shift 4
    mkdir -p "$(dirname "${result}")"
    if [[ -n "${UI_TEST_CONFIGURATION:-}" ]]; then
      set -- "$@" -only-test-configuration "$UI_TEST_CONFIGURATION"
    fi
    suites=()
    while IFS= read -r suite; do
      [[ -z "$suite" ]] && continue
      suites+=("-only-testing:$UI_TEST_TARGET/$suite")
    done <<< "${UI_TEST_SUITES:-}"
    status=0
    run_tests "$result" "$@" ${suites[@]+"${suites[@]}"} || status=$?
    [[ "$status" -eq 0 ]] && exit 0
    # A run that failed without a failed test (no result bundle, a build or device error) is not
    # retried: there is nothing to select, and rerunning everything would hide the error.
    failed=()
    while IFS= read -r filter; do
      [[ -n "$filter" ]] && failed+=("$filter")
    done < <(failed_test_filters "$result")
    [[ "${#failed[@]}" -eq 0 ]] && exit "$status"
    echo "Rerunning ${#failed[@]} failed test(s) once in a new xcodebuild session:"
    printf '  %s\n' "${failed[@]}"
    run_tests "${result%.xcresult}-retry.xcresult" "$@" "${failed[@]}"
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
