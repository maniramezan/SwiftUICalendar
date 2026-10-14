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
    @devices = {
      "devices" => {
        "com.apple.CoreSimulator.SimRuntime.iOS-26-0" => [
          {"name" => "iPhone 17", "deviceTypeIdentifier" => "old-type"}
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-27-0" => [
          {"name" => "iPhone 17", "deviceTypeIdentifier" => "new-type"}
        ]
      }
    }
    File.symlink(RbConfig.ruby, File.join(@directory, "ruby"))
    executable = "#!#{RbConfig.ruby}\n" + <<~'RUBY'
      require "json"
      File.open(ENV.fetch("CALL_LOG"), "a") { |file| file.puts JSON.generate([File.basename($0, ".rb"), *ARGV]) }
      if ARGV[0, 3] == ["simctl", "list", "devices"]
        puts ENV.fetch("DEVICE_JSON")
      elsif ARGV[0, 2] == ["simctl", "create"]
        puts "owned-device"
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

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def run_script(*arguments, **environment)
    Open3.capture2e(
      {"PATH" => "#{@directory}:#{ENV.fetch('PATH')}", "CALL_LOG" => @log,
       "DEVICE_JSON" => JSON.generate(@devices)}.merge(environment.transform_keys(&:to_s)),
      "bash", SCRIPT, *arguments, chdir: @directory
    )
  end

  def calls
    File.readlines(@log).map { |line| JSON.parse(line) }
  end

  def test_creates_fresh_device_on_newest_runtime_without_erasing_existing_devices
    output, status = run_script("create", "iPhone 17")
    assert status.success?, output
    assert_equal "owned-device\n", output
    assert_equal ["xcrun", "simctl", "create"], calls.last[0, 3]
    assert_equal ["new-type", "com.apple.CoreSimulator.SimRuntime.iOS-27-0"], calls.last.last(2)
    assert_equal 2, calls.count
  end

  def test_missing_template_fails_without_mutating_devices
    output, status = run_script("create", "missing")
    refute status.success?
    assert_includes output, "no available missing simulator"
    assert_equal 1, calls.count
  end

  def test_wait_only_uses_bootstatus
    output, status = run_script("wait", "owned-device")
    assert status.success?, output
    assert_equal [["xcrun", "simctl", "bootstatus", "owned-device", "-b"]], calls
  end

  def test_test_plan_reuses_products_and_preserves_flags_and_failure_without_retry
    output, status = run_script("test", "owned-device", "Locales", "results/locales.xcresult",
                                "-test-timeouts-enabled", "YES", TEST_EXIT: "65")
    assert_equal 65, status.exitstatus, output
    assert_equal [["xcodebuild", "test-without-building", "-testProductsPath",
                   ".build/SampleUITests.xctestproducts", "-testPlan", "Locales", "-destination",
                   "id=owned-device", "-test-timeouts-enabled", "YES", "-resultBundlePath",
                   "results/locales.xcresult"]], calls
  end

  def test_deletes_only_owned_device_even_if_shutdown_fails
    output, status = run_script("delete", "owned-device", SIM_EXIT: "1")
    refute status.success?, output
    assert_equal [["xcrun", "simctl", "shutdown", "owned-device"],
                  ["xcrun", "simctl", "delete", "owned-device"]], calls
  end
end
