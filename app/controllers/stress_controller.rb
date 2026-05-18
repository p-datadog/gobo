class StressController < ActionController::Base
  CPU_CHUNK_ITERATIONS = 100_000

  def simple
    render plain: 'ok'
  end

  def cpu1s
    cpu_burn(1.0)
    render plain: 'ok'
  end

  def mix2s
    5.times do
      cpu_burn(0.2)
      sleep 0.2
    end
    render plain: 'ok'
  end

  def io2s
    sleep 2.0
    render plain: 'ok'
  end

  private

  def cpu_burn(seconds)
    target = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < target
      x = 0
      CPU_CHUNK_ITERATIONS.times { |i| x += i * i }
    end
  end
end
