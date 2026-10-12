require 'digest'

module Stress
  # Spawns worker threads that each run a short digest workload, and builds the
  # payload reporting the spawn count.
  class ThreadStress
    DEFAULT_THREAD_COUNT = 20
    WORK_DIGEST_ROUNDS = 1_000
    WORK_SLEEP_SECONDS = 0.1

    # thread_count is the single source of truth for the number of threads
    # handle spawns.
    attr_accessor :thread_count

    def initialize
      @thread_count = DEFAULT_THREAD_COUNT
    end

    # Returns at once — handle never waits for the spawned threads to finish.
    def handle
      threads = Array.new(thread_count) { Thread.new { work } }
      warn "thread stress: spawned #{threads.size} threads"
      payload_for(threads)
    end

    # Builds the JSON payload — thread_count and completed both report the
    # number of spawned threads.
    def payload_for(threads)
      {
        thread_count: threads.size,
        completed: threads.size,
      }
    end

    private

    # Runs 1,000 SHA256 digest rounds and then sleeps 0.1 seconds.
    def work
      WORK_DIGEST_ROUNDS.times { Digest::SHA256.digest('gobo thread stress') }
      sleep WORK_SLEEP_SECONDS
    end
  end
end
