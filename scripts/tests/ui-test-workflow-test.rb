require "minitest/autorun"
require "yaml"
require "json"
require "open3"

class UITestWorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  JOBS = YAML.load_file(File.join(ROOT, ".github/workflows/build.yml")).fetch("jobs")

  def test_matrix_runs_every_default_suite_and_locale_exactly_once
    matrix = JOBS.fetch("ui-test-plans").fetch("strategy").fetch("matrix").fetch("include")
    default = matrix.select { |entry| entry.fetch("plan") == "SwiftUICalendarSample" }
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
    assert_equal expected.count + default.count, matrix.count
    matrix.reject { |entry| entry.fetch("plan") == "SwiftUICalendarSample" }.each do |entry|
      assert_nil entry["suites"], "Locale jobs must run the complete locale plan"
    end
    assert_equal false, JOBS.fetch("ui-test-plans").fetch("strategy").fetch("fail-fast")
  end

  def test_watchdog_leaves_time_for_cleanup_and_diagnostics_before_github_timeout
    plans = JOBS.fetch("ui-test-plans")
    step = plans.fetch("steps").find { |entry| entry.fetch("name") == "Run UI test plan" }
    command = step.fetch("run")
    assert_includes command, "ruby ./scripts/test-watchdog.rb"
    assert_includes command, "--diagnostics .build/results/watchdog"
    seconds = command.match(/--timeout (\d+)/)[1].to_i
    assert_operator seconds, :>, 0
    assert_operator seconds + 120, :<, step.fetch("timeout-minutes") * 60
    assert_operator step.fetch("timeout-minutes") + 5, :<=, plans.fetch("timeout-minutes")
    refute_match(/-(?:parallel-testing-enabled|parallel-testing-worker-count|maximum-parallel-testing-workers)/,
                 command)
  end

  def test_worker_template_is_prepared_and_stopped_before_xcode_starts
    steps = JOBS.fetch("ui-test-plans").fetch("steps")
    prepare = steps.index { |entry| entry.fetch("name") == "Prepare UI test simulator" }
    run = steps.index { |entry| entry.fetch("name") == "Run UI test plan" }
    assert_operator prepare, :<, run
    assert_includes steps.fetch(prepare).fetch("run"), 'prepare "$SIMULATOR_UDID"'
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
    assert_equal %w[ui-test-build ui-test-plans], gate.fetch("needs")
    assert_includes gate.fetch("if"), "always()"
    command = gate.fetch("steps").first.fetch("run")
    %w[success failure cancelled skipped].repeated_permutation(2) do |build, plans|
      output, status = Open3.capture2e({"BUILD_RESULT" => build, "PLANS_RESULT" => plans},
                                      "bash", "-c", command)
      assert_equal build == "success" && plans == "success", status.success?,
                   "build=#{build}, plans=#{plans}: #{output}"
    end
  end
end
