require "minitest/autorun"
require "tmpdir"
require "json"
require "open3"
require "fileutils"
require "rbconfig"

class CheckCoverageTest < Minitest::Test
  SCRIPT = File.expand_path("../check-coverage.sh", __dir__)

  def test_gate_includes_every_package_target_and_excludes_dependencies
    Dir.mktmpdir("calendar-coverage-") do |directory|
      files = %w[SwiftUICalendar SwiftUICalendarTCA SwiftUICalendarAccessibility].map do |target|
        coverage_file(directory, "Sources/#{target}/Example.swift", 1)
      end
      files << coverage_file(directory, ".build/checkouts/Dependency/Sources/Dependency.swift", 0)
      path = File.join(directory, "coverage.json")
      File.write(path, JSON.generate({"data" => [{"files" => files}]}))
      swift = File.join(directory, "swift")
      File.write(swift, "#!#{RbConfig.ruby}\nputs ENV.fetch('COVERAGE_JSON') if ARGV.include?('--show-codecov-path')\n")
      File.chmod(0755, swift)
      environment = {"PATH" => "#{directory}:#{ENV.fetch('PATH')}", "COVERAGE_JSON" => path,
                     "SOURCE_ROOT" => "Sources", "MINIMUM_COVERAGE" => "80"}
      output, status = Open3.capture2e(environment, "bash", SCRIPT, chdir: directory)
      assert status.success?, output
      assert_includes output, "100.00% (3/3 lines)"

      files[1]["segments"][0][2] = 0
      files[2]["segments"][0][2] = 0
      File.write(path, JSON.generate({"data" => [{"files" => files}]}))
      output, status = Open3.capture2e(environment, "bash", SCRIPT, chdir: directory)
      refute status.success?, output
      assert_includes output, "33.33%"
    end
  end

  def coverage_file(directory, relative_path, count)
    path = File.join(directory, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "let value = 1\n")
    {"filename" => path, "segments" => [[1, 1, count, true]]}
  end
end
