require "minitest/autorun"
require "open3"
require "tmpdir"
require "rbconfig"

class TestWatchdogTest < Minitest::Test
  SCRIPT = File.expand_path("../test-watchdog.rb", __dir__)

  def run_command(code, timeout: 5)
    Dir.mktmpdir("calendar-watchdog-") do |directory|
      output, status = Open3.capture2e(
        RbConfig.ruby, SCRIPT, "--timeout", timeout.to_s, "--diagnostics", directory,
        "--", RbConfig.ruby, "-e", code
      )
      yield output, status.exitstatus, directory
    end
  end

  def test_success_and_output_are_preserved
    run_command('puts "ready"') do |output, code, directory|
      assert_equal 0, code
      assert_includes output, "ready"
      assert_includes File.read(File.join(directory, "test-output.log")), "ready"
    end
  end

  def test_failure_exit_code_is_preserved
    run_command("exit 7") { |_, code, _| assert_equal 7, code }
  end

  def test_timeout_kills_the_owned_process_group_and_captures_diagnostics
    run_command('child = spawn(RbConfig.ruby, "-e", "sleep 30"); puts child; STDOUT.flush; sleep 30', timeout: 0.2) do |output, code, directory|
      assert_equal 124, code, output
      assert File.file?(File.join(directory, "processes.txt"))
      child = output.lines.find { |line| line.strip.match?(/\A\d+\z/) }.to_i
      assert_operator child, :>, 0
      state = IO.popen(["ps", "-p", child.to_s, "-o", "stat="], &:read).strip
      assert(state.empty? || state.start_with?("Z"), "Owned child is still running: #{state}")
    end
  end

  def test_timeout_escalates_when_term_is_ignored
    run_command('trap("TERM") {}; sleep 30', timeout: 0.2) do |output, code, _|
      assert_equal 124, code, output
    end
  end

  def test_timeout_kills_children_that_create_their_own_process_group
    sentinel = Process.spawn(RbConfig.ruby, "-e", "sleep 30")
    run_command('child = spawn(RbConfig.ruby, "-e", "Process.setsid; trap(\"TERM\") {}; sleep 30"); puts child; STDOUT.flush; sleep 30', timeout: 0.5) do |output, code, directory|
      assert_equal 124, code, output
      child = output.lines.find { |line| line.strip.match?(/\A\d+\z/) }.to_i
      assert_operator child, :>, 0
      assert_includes File.read(File.join(directory, "processes.txt")), child.to_s
      state = IO.popen(["ps", "-p", child.to_s, "-o", "stat="], &:read).strip
      assert(state.empty? || state.start_with?("Z"), "Detached owned child is still running: #{state}")
      assert Process.kill(0, sentinel), "Unrelated process was stopped"
    end
  ensure
    Process.kill("TERM", sentinel) if sentinel
    Process.waitpid(sentinel) if sentinel
  end

  def test_success_cleans_up_background_children
    run_command('child = spawn(RbConfig.ruby, "-e", "Process.setsid; sleep 30"); puts child; STDOUT.flush; sleep 0.5') do |output, code, _|
      assert_equal 0, code, output
      child = output.lines.find { |line| line.strip.match?(/\A\d+\z/) }.to_i
      assert_operator child, :>, 0
      state = IO.popen(["ps", "-p", child.to_s, "-o", "stat="], &:read).strip
      assert(state.empty? || state.start_with?("Z"), "Detached owned child is still running: #{state}")
    end
  end

  def test_identity_survives_a_detached_child_exec
    run_command('child = spawn(RbConfig.ruby, "-e", "Process.setsid; sleep 0.5; exec(\"/bin/sleep\", \"30\")"); puts child; STDOUT.flush; sleep 30', timeout: 1) do |output, code, _|
      assert_equal 124, code, output
      child = output.lines.find { |line| line.strip.match?(/\A\d+\z/) }.to_i
      assert_operator child, :>, 0
      state = IO.popen(["ps", "-p", child.to_s, "-o", "stat="], &:read).strip
      assert(state.empty? || state.start_with?("Z"), "Exec'd owned child is still running: #{state}")
    end
  end

  def test_cancellation_is_forwarded_and_bounded
    Dir.mktmpdir("calendar-watchdog-cancellation-") do |directory|
      Open3.popen2e(
        RbConfig.ruby, SCRIPT, "--timeout", "30", "--diagnostics", directory,
        "--", RbConfig.ruby, "-e", 'trap("TERM") {}; puts "ready"; STDOUT.flush; sleep 30'
      ) do |input, output, process|
        input.close
        assert_equal "ready\n", output.gets
        Process.kill("TERM", process.pid)
        assert process.join(5), "Cancellation did not finish within five seconds"
        assert_equal 143, process.value.exitstatus, output.read
      end
    end
  end
end
