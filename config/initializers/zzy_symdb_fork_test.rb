# Test scaffolding: route Datadog.logger to stdout with PID-prefixed lines so
# we can attribute symdb / RC events to each Puma worker (and the parent).
# Gated on SYMDB_FORK_TEST=1 so it does not affect normal runs.
# Local-only — not intended for commit.

if ENV['SYMDB_FORK_TEST'] == '1'
  require 'logger'

  logger = Logger.new($stdout)
  logger.formatter = proc do |sev, time, _prog, msg|
    "#{time.strftime('%H:%M:%S.%3N')} [#{sev}] pid=#{Process.pid} ppid=#{Process.ppid} #{msg}\n"
  end

  Datadog.configure do |c|
    c.logger.instance = logger
    c.logger.level = Logger::DEBUG
  end

  $stdout.sync = true
  logger.info("SYMDB_FORK_TEST: process online")
end
