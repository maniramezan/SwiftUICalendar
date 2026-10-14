#!/usr/bin/env ruby

require "fileutils"
require "optparse"

# A SwiftUI callback can block the main run loop, preventing in-process test timeouts.
# Track only owned descendants, including SwiftPM helpers that create a new process group.
# Polling cannot capture an instantaneous double-fork; this is not general sandbox containment.
options = { timeout: 900, diagnostics: ".build/test-diagnostics" }
parser = OptionParser.new do |flags|
  flags.on("--timeout SECONDS", Float) { |value| options[:timeout] = value }
  flags.on("--diagnostics PATH") { |value| options[:diagnostics] = value }
end
parser.order!(ARGV)
abort "Usage: test-watchdog.rb [options] -- command [arguments]" if ARGV.empty?
abort "Timeout must be finite and positive" unless options[:timeout].finite? && options[:timeout].positive?

directory = File.expand_path(options[:diagnostics])
FileUtils.mkdir_p(directory)
log = File.open(File.join(directory, "test-output.log"), "w")
reader, writer = IO.pipe
pid = Process.spawn({ "NSUnbufferedIO" => "YES" }, *ARGV, out: writer, err: writer, pgroup: true)
owned = {}
snapshot = lambda do
  IO.popen(["ps", "-axo", "pid=,ppid=,uid=,lstart=,comm="], &:read).lines.each_with_object({}) do |line, entries|
    fields = line.strip.split(/\s+/, 9)
    next unless fields.length == 9
    entries[fields[0].to_i] = {
      parent: fields[1].to_i,
      identity: [fields[2], fields[3..7].join(" ")],
      name: fields[8]
    }
  end
end
refresh_owned = lambda do
  current = snapshot.call
  root = current[pid]
  owned[pid] ||= root[:identity] if root
  loop do
    added = false
    current.each do |child, entry|
      parent = current[entry[:parent]]
      next unless parent && owned[entry[:parent]] == parent[:identity]
      next if owned.key?(child)
      owned[child] = entry[:identity]
      added = true
    end
    break unless added
  end
  current.select { |child, entry| owned[child] == entry[:identity] }
end
signal_owned = lambda do |signal|
  refresh_owned.call.each_key do |child|
    begin
      Process.kill(signal, child)
    rescue Errno::ESRCH
      # An owned process can exit between the snapshot and signal.
    end
  end
end
begin
  writer.close
  stream = Thread.new do
    console_open = true
    reader.each_line do |line|
      log.write(line)
      log.flush
      next unless console_open
      # Keep the complete output on disk. Console delivery is best effort under backpressure.
      begin
        offset = 0
        while offset < line.bytesize
          written = STDOUT.write_nonblock(line.byteslice(offset..-1), exception: false)
          break unless written.is_a?(Integer)
          offset += written
        end
      rescue IOError, Errno::EPIPE
        console_open = false
      end
    end
  rescue IOError
    raise unless reader.closed?
  ensure
    reader.close
    log.close
  end

  signal_group = lambda do |signal|
    Process.kill(signal, -pid)
  rescue Errno::ESRCH
    # The owned command may have completed while the timeout was being delivered.
  rescue Errno::EPERM
    # Darwin can report EPERM for a process group containing only unreaped zombies.
    live = IO.popen(["ps", "-axo", "pgid=,stat="], &:read).lines.any? do |line|
      group, state = line.strip.split(/\s+/, 2)
      group.to_i == pid && !state.start_with?("Z")
    end
    raise if live
  end
  %w[INT TERM].each do |signal|
    Signal.trap(signal) { @cancelled_signal = signal }
  end

  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + options[:timeout]
  next_snapshot = 0
  status = nil
  until status
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    if now >= next_snapshot
      refresh_owned.call
      next_snapshot = now + 0.25
    end
    waited = Process.waitpid2(pid, Process::WNOHANG)
    if waited
      status = waited.last
      break
    end
    if @cancelled_signal || now >= deadline
      reason = @cancelled_signal ? "received #{@cancelled_signal}" : "exceeded #{options[:timeout]} seconds"
      message = "Test command #{reason}; collecting diagnostics in #{directory}"
      File.write(File.join(directory, "termination.txt"), "#{message}\n")
      # A stalled console consumer must not block termination before signals are delivered.
      begin
        STDERR.write_nonblock("#{message}\n", exception: false)
      rescue IOError, Errno::EPIPE
        # The diagnostics file remains available if the console is closed.
      end
      # ps emits executable names, not command arguments or unrelated processes' data.
      processes = refresh_owned.call.map { |process_id, entry| [process_id, entry[:name]] }
      File.write(File.join(directory, "processes.txt"), processes.map { |entry| entry.join(" ") }.join("\n"))
      if RUBY_PLATFORM.include?("darwin")
        processes.select { |_, name| name.include?("swiftpm-testing") }.first(3).each do |process_id, _|
          system("/usr/bin/sample", process_id.to_s, "1", "-file",
                 File.join(directory, "sample-#{process_id}.txt"), out: File::NULL, err: File::NULL)
        end
      end
      signal_owned.call(@cancelled_signal || "TERM")
      signal_group.call(@cancelled_signal || "TERM")
      grace = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
      until status || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= grace
        waited = Process.waitpid2(pid, Process::WNOHANG)
        status = waited.last if waited
        sleep 0.05 unless status
      end
      signal_owned.call("KILL")
      signal_group.call("KILL")
      Process.waitpid(pid) unless status
      unless stream.join(1)
        # The stream may be blocked writing to the console, not reading the child pipe.
        stream.kill
        stream.join
      end
      exit(@cancelled_signal ? 128 + Signal.list.fetch(@cancelled_signal) : 124)
    end
    sleep 0.05
  end

  # A command that left children holding its output pipe must not keep the watchdog alive.
  signal_group.call("TERM")
  signal_owned.call("TERM")
  unless stream.join(1)
    signal_owned.call("KILL")
    signal_group.call("KILL")
    stream.kill
    stream.join
  end
  exit(status.exitstatus || 128 + status.termsig)
ensure
  begin
    signal_owned.call("KILL")
    signal_group.call("KILL") if signal_group
  rescue Errno::ESRCH
    # Cleanup is idempotent when the owned group has already exited.
  end
  reader.close unless reader.closed?
  writer.close unless writer.closed?
end
