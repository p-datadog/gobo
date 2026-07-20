require 'fileutils'
require 'set'

# Records the DI runtime id of each live worker process of this server so the
# DI Status page can highlight which backend-reported runtime ids belong to the
# currently running process. Each worker writes <dir>/<pid> = runtime_id on
# boot; readers drop entries whose pid is no longer alive, so the directory
# self-prunes across restarts without a separate cleanup step.
#
# runtime_id is Datadog::Core::Environment::Identity.id, which is regenerated
# per process after fork — the same value the tracer reports in DI heartbeats
# and APM instance telemetry.
class RuntimeIdRegistry
  def initialize(dir, process_checker: nil)
    @dir = dir.to_s
    @process_checker = process_checker
  end

  def record(runtime_id:, pid: Process.pid)
    return if runtime_id.nil? || runtime_id.to_s.strip.empty?

    FileUtils.mkdir_p(@dir)
    File.write(File.join(@dir, pid.to_s), runtime_id.to_s)
  end

  # Runtime ids of processes that are still alive. Files for dead pids are
  # deleted as a side effect so stale entries do not accumulate.
  def live_runtime_ids
    entries.each_with_object(Set.new) do |(pid, file), ids|
      if alive?(pid)
        id = read(file)
        ids << id unless id.empty?
      else
        delete(file)
      end
    end
  end

  private

  def entries
    return [] unless File.directory?(@dir)

    Dir.children(@dir).filter_map do |name|
      next unless name.match?(/\A\d+\z/)

      [name.to_i, File.join(@dir, name)]
    end
  end

  def read(file)
    File.read(file).strip
  rescue Errno::ENOENT
    ''
  end

  def delete(file)
    File.delete(file)
  rescue Errno::ENOENT
    nil
  end

  def alive?(pid)
    return @process_checker.call(pid) if @process_checker

    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end
end
