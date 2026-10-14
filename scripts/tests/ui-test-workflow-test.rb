require "minitest/autorun"
require "yaml"
require "json"
require "open3"

class UITestWorkflowTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  JOBS = YAML.load_file(File.join(ROOT, ".github/workflows/build.yml")).fetch("jobs")

  def test_matrix_runs_default_plan_and_every_locale_exactly_once
    matrix = JOBS.fetch("ui-test-plans").fetch("strategy").fetch("matrix").fetch("include")
    default = matrix.select { |entry| entry.fetch("plan") == "SwiftUICalendarSample" }
    assert_equal 1, default.count
    assert_equal "", default.first.fetch("configuration")

    plan = JSON.parse(File.read(File.join(ROOT,
      "Examples/SwiftUICalendarSample/SwiftUICalendarSampleLocales.xctestplan")))
    expected = plan.fetch("configurations").map { |entry| entry.fetch("name") }.sort
    actual = matrix.select { |entry| entry.fetch("plan") == "SwiftUICalendarSampleLocales" }
                   .map { |entry| entry.fetch("configuration") }.sort
    assert_equal expected, actual
    assert_equal expected.count + 1, matrix.count
    assert_equal false, JOBS.fetch("ui-test-plans").fetch("strategy").fetch("fail-fast")
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
