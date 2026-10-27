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
      if ARGV[0, 3] == ["simctl", "list", "runtimes"]
        puts ENV.fetch("RUNTIME_JSON")
      elsif ARGV[0, 2] == ["simctl", "create"]
        puts "owned-device"
      end
      if File.basename($0, ".rb") == "xcodebuild" && ENV["TEST_HANG"] == "1"
        trap("TERM") {}
        puts "test runner stalled"
        STDOUT.flush
        sleep 30
      end
      exit ENV.fetch(File.basename($0, ".rb") == "xcodebuild" ? "TEST_EXIT" : "SIM_EXIT", "0").to_i
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

  def run_script(*arguments, watchdog_timeout: nil, **environment)
    command = ["bash", SCRIPT, *arguments]
    if watchdog_timeout
      command = [RbConfig.ruby, File.expand_path("../test-watchdog.rb", __dir__),
                 "--timeout", watchdog_timeout.to_s, "--diagnostics", "results/watchdog", "--", *command]
    end
    Open3.capture2e(
      {"PATH" => "#{@directory}:#{ENV.fetch('PATH')}", "CALL_LOG" => @log,
       "RUNTIME_JSON" => JSON.generate(@inventory)}.merge(environment.transform_keys(&:to_s)),
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
  end

  def test_prepare_failure_fails_the_job_instead_of_testing_a_half_booted_device
    _, status = run_script("prepare", "owned-device", SIM_EXIT: "1")
    refute status.success?
  end

  def test_tests_never_run_in_parallel_clones
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult")
    assert status.success?, output
    arguments = calls.first
    assert_equal "NO", arguments[arguments.index("-parallel-testing-enabled") + 1]
  end

  def test_missing_device_type_fails_without_mutating_devices
    output, status = run_script("create", "missing")
    refute status.success?
    assert_includes output, "no available iOS runtime supports missing"
    assert_equal 1, calls.count
  end

  def test_test_plan_reuses_products_and_preserves_flags_and_failure_without_retry
    output, status = run_script("test", "owned-device", "Locales", "results/locales.xcresult",
                                "-test-timeouts-enabled", "YES", TEST_EXIT: "65", watchdog_timeout: 5)
    assert_equal 65, status.exitstatus, output
    assert_equal [["xcodebuild", "test-without-building", "-testProductsPath",
                   ".build/SampleUITests.xctestproducts", "-testPlan", "Locales", "-destination",
                   "id=owned-device", "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES",
                   "-resultBundlePath",
                   "results/locales.xcresult", "-resultStreamPath", "results/locales.events.jsonl"]], calls
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

  def test_watchdog_stops_a_hung_test_command_and_retains_output_without_retry
    output, status = run_script("test", "owned-device", "Default", "results/tests.xcresult",
                                TEST_HANG: "1", watchdog_timeout: 2)
    assert_equal 124, status.exitstatus, output
    assert_equal 1, calls.count
    assert_includes File.read(File.join(@directory, "results/watchdog/test-output.log")),
                    "test runner stalled"
    assert File.file?(File.join(@directory, "results/watchdog/processes.txt"))
    assert File.file?(File.join(@directory, "results/tests.events.jsonl"))
  end

  def test_deletes_only_owned_device_even_if_shutdown_fails
    output, status = run_script("delete", "owned-device", SIM_EXIT: "1")
    refute status.success?, output
    assert_equal [["xcrun", "simctl", "shutdown", "owned-device"],
                  ["xcrun", "simctl", "delete", "owned-device"]], calls
  end
end
