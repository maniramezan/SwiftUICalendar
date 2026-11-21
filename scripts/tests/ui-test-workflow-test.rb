require "minitest/autorun"
require "yaml"
require "json"
require "open3"

class UITestWorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  JOBS = YAML.load_file(File.join(ROOT, ".github/workflows/build.yml")).fetch("jobs")

  def test_matrix_runs_every_default_suite_and_locale_exactly_once
    matrix = JOBS.fetch("ui-test-plans").fetch("strategy").fetch("matrix").fetch("include")
    default = matrix.select { |entry| entry.fetch("plan") == "SwiftUICalendarSample" && !entry.key?("device") }
    classes = Dir.glob(File.join(ROOT, "Examples/SwiftUICalendarSample/UITests/*.swift"))
                 .flat_map { |path| File.read(path).scan(/class\s+(\w+)\s*:\s*SampleUITestCase\b/).flatten }
    default_plan = JSON.parse(File.read(File.join(ROOT,
      "Examples/SwiftUICalendarSample/SwiftUICalendarSample.xctestplan")))
    skipped = default_plan.fetch("testTargets").first.fetch("skippedTests")
    expected_suites = (classes - skipped).sort
    actual_suites = default.flat_map { |entry| entry.fetch("suites").split }
    assert_equal expected_suites, actual_suites.sort,
                 "Every default suite must run exactly once, including newly added suites"
    default.each do |entry|
      assert_equal "", entry.fetch("configuration")
      refute_empty entry.fetch("suites")
    end

    plan = JSON.parse(File.read(File.join(ROOT,
      "Examples/SwiftUICalendarSample/SwiftUICalendarSampleLocales.xctestplan")))
    expected = plan.fetch("configurations").map { |entry| entry.fetch("name") }.sort
    actual = matrix.select { |entry| entry.fetch("plan") == "SwiftUICalendarSampleLocales" }
                   .map { |entry| entry.fetch("configuration") }.sort
    assert_equal expected, actual
    assert_equal expected.count + default.count + 4, matrix.count
    matrix.reject { |entry| entry.fetch("plan") == "SwiftUICalendarSample" }.each do |entry|
      assert_nil entry["suites"], "Locale jobs must run the complete locale plan"
    end
    assert_equal false, JOBS.fetch("ui-test-plans").fetch("strategy").fetch("fail-fast")
  end

  def test_device_matrix_exercises_dynamic_type_on_small_phone_large_phone_and_tablet
    plans = JOBS.fetch("ui-test-plans")
    matrix = plans.fetch("strategy").fetch("matrix").fetch("include")
    devices = matrix.select { |entry| entry.key?("device") }
    dynamic_type = devices.select { |entry| entry.fetch("suites") == "DynamicTypeUITests" }
    assert_equal ["iPhone SE (3rd generation)", "iPhone 17 Pro Max", "iPad Pro 13-inch (M5)"],
                 dynamic_type.map { |entry| entry.fetch("device") }
    # Paging races surfaced only on large screens, so selection also runs on the tablet.
    assert_equal [["iPad Pro 13-inch (M5)", "SelectionUITests"]],
                 (devices - dynamic_type).map { |entry| [entry.fetch("device"), entry.fetch("suites")] }
    assert_includes plans.fetch("env").fetch("DEVICE_NAME"), "matrix.device"
    job = JOBS.fetch("ios-package-tests")
    commands = job.fetch("steps").map { |step| step.fetch("run", "") }.join("\n")
    assert_includes commands, "xcodebuild build-for-testing -scheme SwiftUICalendar-Package"
    assert_includes commands, "xcodebuild test-without-building"
    assert_includes commands, "-destination \"id=$SIMULATOR_UDID\""
    assert_includes commands, "ui-test-simulator.sh prepare"
    assert_includes commands, "ui-test-simulator.sh delete"
  end

  # Both xcodebuild jobs reuse cached package checkouts, and the iPad job builds before it boots
  # the simulator so the two never compete for the runner's CPU.
  def test_xcodebuild_jobs_reuse_cached_packages_and_build_before_booting
    %w[ui-test-build ios-package-tests].each do |name|
      steps = JOBS.fetch(name).fetch("steps")
      cache = steps.find { |entry| entry.fetch("uses", "").start_with?("actions/cache@") }
      refute_nil cache, "#{name} has no package cache"
      assert_equal "SwiftUICalendar/.build/xcode-packages", cache.fetch("with").fetch("path")
      commands = steps.map { |entry| entry.fetch("run", "") }.join("\n")
      assert_includes commands, "-clonedSourcePackagesDirPath .build/xcode-packages"
    end
    steps = JOBS.fetch("ios-package-tests").fetch("steps")
    build = steps.index { |entry| entry.fetch("run", "").include?("build-for-testing") }
    boot = steps.index { |entry| entry.fetch("run", "").include?("ui-test-simulator.sh prepare") }
    run = steps.index { |entry| entry.fetch("run", "").include?("test-without-building") }
    assert_operator build, :<, boot
    assert_operator boot, :<, run
  end

  # GitHub's step timeout stops a hung test run; the job must outlast it by enough to delete the
  # simulator and upload the result bundle, which runs even after a timeout.
  def test_step_timeout_leaves_time_for_cleanup_and_upload
    {
      "ui-test-plans" => ["Run UI test plan", 40, "Upload test results"],
      "ios-package-tests" => ["Run iOS package tests", 30, "Upload iPad package results"]
    }.each do |job_name, (test_step_name, test_timeout, upload_step_name)|
      job = JOBS.fetch(job_name)
      steps = job.fetch("steps")
      test_index = steps.index { |entry| entry.fetch("name") == test_step_name }
      assert_equal test_timeout, steps.fetch(test_index).fetch("timeout-minutes")
      timed_steps = steps.take(test_index + 1).sum { |entry| entry.fetch("timeout-minutes", 0) }
      assert_operator timed_steps + 5, :<=, job.fetch("timeout-minutes")
      upload = steps.find { |entry| entry.fetch("name") == upload_step_name }
      assert_equal "always()", upload.fetch("if")
    end
  end

  def test_ipad_package_tests_capture_progress_without_verbose_diagnostics
    steps = JOBS.fetch("ios-package-tests").fetch("steps")
    command = steps.find { |entry| entry.fetch("name") == "Run iOS package tests" }.fetch("run")
    stream = ".build/results/ipad-package.events.jsonl"
    assert_includes command, "touch #{stream}"
    assert_includes command, "-resultStreamPath #{stream}"
    assert_includes command, "-resultBundlePath .build/results/ipad-package.xcresult"
    assert_includes command, "-collect-test-diagnostics never"
  end

  # Xcode clones and cold-boots its own devices for parallel testing, so warming the owned device only
  # helps when the tests run on it directly. Both halves are required: warm it, and keep Xcode from
  # cloning it. Each plan has its own runner, so serial execution within a job is cheap.
  def test_tests_run_serially_on_a_device_settled_before_xcode_starts
    plans = JOBS.fetch("ui-test-plans")
    steps = plans.fetch("steps")
    create = steps.index { |entry| entry.fetch("name") == "Create UI test simulator" }
    prepare = steps.index { |entry| entry.fetch("run", "").include?("ui-test-simulator.sh prepare") }
    run = steps.index { |entry| entry.fetch("name") == "Run UI test plan" }
    refute_nil prepare, "The simulator must be booted and settled before the tests"
    assert_operator create, :<, prepare
    assert_operator prepare, :<, run
    assert steps.fetch(prepare).key?("timeout-minutes"), "A stuck boot must not consume the job"
    script = File.read(File.join(ROOT, "scripts/ui-test-simulator.sh"))
    assert_match(/-parallel-testing-enabled NO/, script)
    command = steps.fetch(run).fetch("run")
    refute_match(/-(?:parallel-testing-worker-count|maximum-parallel-testing-workers)/, command)
  end

  # A timed-out test is never rerun by xcodebuild, so the script owns the single retry; stacking
  # xcodebuild's iterations on top would run a genuinely failing test four times.
  def test_failed_tests_are_retried_by_the_script_not_by_xcodebuild
    steps = JOBS.fetch("ui-test-plans").fetch("steps")
    command = steps.find { |entry| entry.fetch("name") == "Run UI test plan" }.fetch("run")
    refute_match(/^\s*-retry-tests-on-failure/, command)
    refute_match(/^\s*-test-iterations/, command)
    assert_includes command, "-test-timeouts-enabled YES"
    script = File.read(File.join(ROOT, "scripts/ui-test-simulator.sh"))
    assert_includes script, "-retry.xcresult"
  end

  def test_ui_jobs_share_one_exported_build
    build = JOBS.fetch("ui-test-build").fetch("steps")
    plans = JOBS.fetch("ui-test-plans")
    assert_equal ["ui-test-build"], Array(plans.fetch("needs"))
    commands = (build + plans.fetch("steps")).map { |step| step.fetch("run", "") }
    assert_equal 1, commands.join("\n").scan(/xcodebuild\s+build-for-testing/).count
    upload = build.find { |step| step.fetch("name") == "Upload UI test products" }
    download = plans.fetch("steps").find { |step| step.fetch("name") == "Download UI test products" }
    assert_equal upload.fetch("with").fetch("name"), download.fetch("with").fetch("name")
    assert upload.fetch("with").fetch("path").end_with?(".tar.gz"),
           "The archive must preserve executable permissions and symlinks"
  end

  def test_required_check_rejects_build_or_matrix_failures_and_skips
    gate = JOBS.fetch("ui-tests")
    assert_equal %w[ui-test-build ui-test-plans ios-package-tests], gate.fetch("needs")
    assert_includes gate.fetch("if"), "always()"
    command = gate.fetch("steps").first.fetch("run")
    %w[success failure cancelled skipped].repeated_permutation(3) do |build, plans, package|
      output, status = Open3.capture2e({"BUILD_RESULT" => build, "PLANS_RESULT" => plans, "PACKAGE_RESULT" => package},
                                      "bash", "-c", command)
      assert_equal build == "success" && plans == "success" && package == "success", status.success?,
                   "build=#{build}, plans=#{plans}: #{output}"
    end
  end
end
