require 'objspace'
require_relative '../../lib/memory_stats'

class MemoryController < ApplicationController
  def index
    @fast = MemoryStats.snapshot
    @deep = MemoryStats.object_stats
    @stats = @fast.merge(
      heap_measured_mb: @deep[:total_memsize_mb],
      top_by_count: @deep[:by_count],
      top_by_size: @deep[:by_size],
    )
    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end

  def fast
    @stats = MemoryStats.snapshot
    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
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
