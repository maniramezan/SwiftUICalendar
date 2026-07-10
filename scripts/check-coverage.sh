#!/usr/bin/env bash

set -euo pipefail

minimum_coverage="${MINIMUM_COVERAGE:-80}"
source_root="${SOURCE_ROOT:-Sources/SwiftUICalendar}"
export MINIMUM_COVERAGE="${minimum_coverage}"
export SOURCE_ROOT="${source_root}"

SNAPSHOT_RENDERING=true swift test --enable-code-coverage

coverage_path="$(swift test --show-codecov-path)"

ruby -rjson -e '
  minimum = Float(ENV.fetch("MINIMUM_COVERAGE"))
  source_root = ENV.fetch("SOURCE_ROOT")
  path = ARGV.fetch(0)
  data = JSON.parse(File.read(path))

  covered_lines = 0
  executable_lines = 0

  data.fetch("data").each do |entry|
    entry.fetch("files").each do |file|
      filename = file.fetch("filename")
      next unless filename.include?("/#{source_root}/")

      preview_start_line = nil
      File.foreach(filename).with_index(1) do |content, line_number|
        if content.start_with?("#Preview")
          preview_start_line = line_number
          break
        end
      end

      segments = file.fetch("segments")
      segments.each_with_index do |segment, index|
        line, _column, count, has_count = segment
        next unless has_count
        next if preview_start_line && line >= preview_start_line

        next_line = segments[index + 1]&.[](0) || line + 1
        next_line = [next_line, preview_start_line].compact.min
        line_count = [next_line - line, 1].max
        executable_lines += line_count
        covered_lines += line_count if count.positive?
      end
    end
  end

  if executable_lines.zero?
    warn "error: no executable lines found under #{source_root}"
    exit 1
  end

  coverage = covered_lines * 100.0 / executable_lines
  puts format("Coverage: %.2f%% (%d/%d lines) for %s", coverage, covered_lines, executable_lines, source_root)

  if coverage < minimum
    warn format("error: coverage %.2f%% is below required %.2f%%", coverage, minimum)
    exit 1
  end
' "${coverage_path}"
