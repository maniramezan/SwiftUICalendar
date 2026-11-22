require "minitest/autorun"
require "open3"
require "tmpdir"
require "json"
require "rbconfig"

class UITestSimulatorTest < Minitest::Test
  SCRIPT = File.expand_path("../ui-test-simulator.sh", __dir__)

  def setup
    @directory = Dir.mktmpdir("calendar-simulator-")
    @log = File.join(@directory, "calls.jsonl")
    @inventory = {
      "runtimes" => [
        runtime("26.0", "old-type"),
        runtime("27.0", "new-type")
      ]
    }
    File.symlink(RbConfig.ruby, File.join(@directory, "ruby"))
    executable = "#!#{RbConfig.ruby}\n" + <<~'RUBY'
      require "json"
      File.open(ENV.fetch("CALL_LOG"), "a") { |file| file.puts JSON.generate([File.basename($0, ".rb"), *ARGV]) }
      if ARGV[0, 2] == ["simctl", "bootstatus"] && ENV["BOOT_LINGER"] == "1"
        puts "Status=4294967295, isTerminal=YES, Elapsed=01:12."
        STDOUT.flush
        sleep 30
      end
      if ARGV[0, 3] == ["simctl", "list", "runtimes"]
        puts ENV.fetch("RUNTIME_JSON")
      elsif ARGV[0, 2] == ["simctl", "create"]
        puts "owned-device"
      end
      if ARGV[0, 4] == ["xcresulttool", "get", "test-results", "tests"]
        puts ENV.fetch("RESULTS_JSON", "{}")
        exit 0
      end
      if File.basename($0, ".rb") == "xcodebuild"
        # TEST_EXIT holds one exit status per xcodebuild session; the last one repeats.
        statuses = ENV.fetch("TEST_EXIT", "0").split(",")
        session = File.readlines(ENV.fetch("CALL_LOG")).count { |line| JSON.parse(line).first == "xcodebuild" }
        bundle = ARGV[ARGV.index("-resultBundlePath") + 1]
        Dir.mkdir(bundle) unless ENV["NO_RESULT_BUNDLE"] == "1" || Dir.exist?(bundle)
        exit statuses.fetch(session - 1, statuses.last).to_i
      end
      exit ENV.fetch("SIM_EXIT", "0").to_i
    RUBY
    %w[xcrun xcodebuild].each do |name|
      path = File.join(@directory, name)
      File.write("#{path}.rb", executable)
      File.write(path, <<~SH)
        #!/bin/bash
        if [[ "$1" == "--sdk" ]]; then
          exec /usr/bin/xcrun "$@"
        fi
        exec #{RbConfig.ruby} #{path}.rb "$@"
      SH
      File.chmod(0755, path)
    end
  end

  def runtime(version, device_type, available: true, platform: "iOS")
    {
      "identifier" => "com.apple.CoreSimulator.SimRuntime.#{platform}-#{version.tr('.', '-')}",
      "version" => version,
      "isAvailable" => available,
      "supportedDeviceTypes" => [{"name" => "iPhone 17", "identifier" => device_type}]
    }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def run_script(*arguments, **environment)
    command = ["bash", SCRIPT, *arguments]
    Open3.capture2e(
      {"PATH" => "#{@directory}:#{ENV.fetch('PATH')}", "CALL_LOG" => @log,
       "RUNTIME_JSON" => JSON.generate(@inventory), "SIMULATOR_QUIET_INTERVAL" => "0"}.merge(environment.transform_keys(&:to_s)),
      *command, chdir: @directory
    )
  end

  def calls
    File.readlines(@log).map { |line| JSON.parse(line) }
  end

  def test_creates_fresh_device_on_newest_supported_runtime_without_a_template
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal "owned-device\n", output
    assert_equal ["xcrun", "simctl", "create"], calls.last[0, 3]
    assert_equal ["new-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"], calls.last.last(2)
    assert_equal 2, calls.count
  end

  def test_newest_runtime_without_the_requested_device_type_is_skipped
    @inventory["runtimes"] << runtime("27.1", "duo-type").merge(
      "supportedDeviceTypes" => [{"name" => "iPhone Duo", "identifier" => "duo-type"}]
    )
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal ["new-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"], calls.last.last(2)
  end

  def test_unavailable_runtime_is_skipped
    @inventory["runtimes"] << runtime("27.1", "unavailable-type", available: false)
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal ["new-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"], calls.last.last(2)
  end

  def test_other_platforms_are_skipped
    @inventory["runtimes"] << runtime("28.0", "other-platform-type", platform: "tvOS")
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal ["new-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"], calls.last.last(2)
  end

  def test_runtime_versions_are_compared_numerically
    @inventory["runtimes"] = [runtime("27.10", "latest-type"), runtime("27.9", "earlier-type")]
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal ["latest-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-10"], calls.last.last(2)
  end

  def test_no_installed_runtimes_fails_without_mutating_devices
    @inventory["runtimes"] = []
    output, status = run_script("create", "iPhone 17")
    refute status.success?
    assert_includes output, "no available iOS runtime supports iPhone 17"
    assert_equal 1, calls.count
  end

  def test_prepare_boots_and_settles_the_device_and_leaves_it_running
    output, status = run_script("prepare", "owned-device")
    assert status.success?, output
    assert_equal [["xcrun", "simctl", "bootstatus", "owned-device", "-b"]], calls
    assert_includes output, "Simulator went quiet"
  end

  # bootstatus can linger for minutes after the device is ready; prepare must not wait for it.
  def test_prepare_returns_at_the_terminal_status_without_waiting_for_bootstatus_to_exit
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    output, status = run_script("prepare", "owned-device", BOOT_LINGER: "1")
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert status.success?, output
    assert_includes output, "isTerminal=YES"
    assert_operator elapsed, :<, 10
  end

  def test_prepare_failure_fails_the_job_instead_of_testing_a_half_booted_device
    _, status = run_script("prepare", "owned-device", SIM_EXIT: "1")
    refute status.success?
  end

  def test_tests_never_run_in_parallel_clones
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult")
    assert status.success?, output
    arguments = sessions.first
    assert_equal "NO", arguments[arguments.index("-parallel-testing-enabled") + 1]
  end

  def test_missing_device_type_fails_without_mutating_devices
    output, status = run_script("create", "missing")
    refute status.success?
    assert_includes output, "no available iOS runtime supports missing"
    assert_equal 1, calls.count
  end

  def failed_results(*identifiers)
    cases = identifiers.map do |identifier|
      {"nodeType" => "Test Case", "nodeIdentifier" => identifier, "result" => "Failed"}
    end
    passed = {"nodeType" => "Test Case", "nodeIdentifier" => "SelectionUITests/testPassed()", "result" => "Passed"}
    JSON.generate("testNodes" => [{"nodeType" => "Test Plan", "result" => "Failed",
                                   "children" => [{"nodeType" => "Test Suite", "result" => "Failed",
                                                   "children" => cases + [passed]}]}])
  end

  def sessions
    calls.select { |call| call.first == "xcodebuild" }
  end

  # A failure with no failed test to select (a build or device error) is reported as it is.
  def test_test_plan_reuses_products_and_preserves_flags_and_failure_without_failed_tests
    output, status = run_script("test", "owned-device", "Locales", "results/locales.xcresult",
                                "-test-timeouts-enabled", "YES", TEST_EXIT: "65")
    assert_equal 65, status.exitstatus, output
    assert_equal [["xcodebuild", "test-without-building", "-testProductsPath",
                   ".build/SampleUITests.xctestproducts", "-testPlan", "Locales", "-destination",
                   "id=owned-device", "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES",
                   "-resultBundlePath",
                   "results/locales.xcresult", "-resultStreamPath", "results/locales.events.jsonl"]], sessions
  end

  def test_failure_without_a_result_bundle_is_not_retried
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult",
                                TEST_EXIT: "70", NO_RESULT_BUNDLE: "1",
                                RESULTS_JSON: failed_results("SelectionUITests/testTimedOut()"))
    assert_equal 70, status.exitstatus, output
    assert_equal 1, sessions.count
  end

  # A timed-out test kills the runner, so xcodebuild's own retry never reruns it; the script does.
  def test_failed_tests_are_rerun_once_in_a_second_session_that_decides_the_result
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult",
                                "-test-timeouts-enabled", "YES",
                                UI_TEST_SUITES: "SelectionUITests\nHeaderControlUITests\n",
                                UI_TEST_CONFIGURATION: "English", TEST_EXIT: "65,0",
                                RESULTS_JSON: failed_results("SelectionUITests/testTimedOut()",
                                                             "HeaderControlUITests/testFailed()"))
    assert status.success?, output
    assert_equal 2, sessions.count
    retry_session = sessions.last
    assert_equal ["-only-testing:SwiftUICalendarSampleUITests/SelectionUITests/testTimedOut",
                  "-only-testing:SwiftUICalendarSampleUITests/HeaderControlUITests/testFailed"],
                 retry_session.select { |argument| argument.start_with?("-only-testing:") }
    assert_equal "results/tests-retry.xcresult", retry_session[retry_session.index("-resultBundlePath") + 1]
    assert_equal "English", retry_session[retry_session.index("-only-test-configuration") + 1]
    assert_equal "YES", retry_session[retry_session.index("-test-timeouts-enabled") + 1]
    assert_equal "NO", retry_session[retry_session.index("-parallel-testing-enabled") + 1]
    assert File.file?(File.join(@directory, "results/tests-retry.events.jsonl"))
  end

  def test_a_test_that_fails_both_sessions_fails_the_job_without_a_third_session
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult",
                                TEST_EXIT: "65", RESULTS_JSON: failed_results("SelectionUITests/testBroken()"))
    assert_equal 65, status.exitstatus, output
    assert_equal 2, sessions.count
  end

  def test_named_configuration_is_forwarded_as_one_argument
    output, status = run_script("test", "owned-device", "Locales", "results/tests.xcresult",
                                "-test-timeouts-enabled", "YES", UI_TEST_CONFIGURATION: "English (US)")
    assert status.success?, output
    assert_equal 1, calls.count
    assert_equal ["-only-test-configuration", "English (US)"], calls.first[-6, 2]
  end

  def test_suite_filter_includes_each_requested_suite_and_creates_live_stream
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult",
                                UI_TEST_SUITES: "HeaderControlUITests\n\nDynamicTypeUITests\n")
    assert status.success?, output
    filters = calls.first.select { |argument| argument.start_with?("-only-testing:") }
    assert_equal ["-only-testing:SwiftUICalendarSampleUITests/HeaderControlUITests",
                  "-only-testing:SwiftUICalendarSampleUITests/DynamicTypeUITests"], filters
    assert File.file?(File.join(@directory, "results/tests.events.jsonl"))
  end

  def test_deletes_only_owned_device_even_if_shutdown_fails
    output, status = run_script("delete", "owned-device", SIM_EXIT: "1")
    refute status.success?, output
    assert_equal [["xcrun", "simctl", "shutdown", "owned-device"],
                  ["xcrun", "simctl", "delete", "owned-device"]], calls
  end
end
