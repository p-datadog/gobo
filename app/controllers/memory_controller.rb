require 'objspace'

class MemoryController < ApplicationController
  def index
    @stats = MemoryStats.snapshot
  end

  def run_gc
    before_rss = MemoryStats.rss_bytes
    3.times { GC.start(full_mark: true, immediate_sweep: true) }
    after_rss = MemoryStats.rss_bytes

    render json: {
      before_rss: before_rss,
      after_rss: after_rss,
      freed: before_rss - after_rss,
      stats: MemoryStats.snapshot,
    }
  end

  def malloc_trim
    before_rss = MemoryStats.rss_bytes
    result = MemoryStats.malloc_trim
    after_rss = MemoryStats.rss_bytes

    render json: {
      before_rss: before_rss,
      after_rss: after_rss,
      freed: before_rss - after_rss,
      trimmed: result,
      stats: MemoryStats.snapshot,
    }
  end
end
