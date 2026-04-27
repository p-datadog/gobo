require 'objspace'
require 'fiddle'

module MemoryStats
  def self.rss_bytes
    `ps -o rss= -p #{$$}`.to_i * 1024
  end

  def self.heap_live_slots
    GC.stat[:heap_live_slots]
  end

  def self.malloc_trim
    fn = Fiddle::Function.new(
      Fiddle::Handle::DEFAULT['malloc_trim'],
      [Fiddle::TYPE_INT], Fiddle::TYPE_INT
    )
    fn.call(0)
  rescue Fiddle::DLError
    nil
  end

  # Fast snapshot using only GC.stat + count_objects (C-level, no Ruby iteration).
  # Safe to call even with DI probes on hot methods.
  def self.snapshot
    gc = GC.stat
    rss = rss_bytes
    counts = ObjectSpace.count_objects

    {
      rss_bytes: rss,
      rss_mb: (rss / 1048576.0).round(1),
      heap_live_slots: gc[:heap_live_slots],
      heap_free_slots: gc[:heap_free_slots],
      heap_live_estimate_mb: (gc[:heap_live_slots] * 40 / 1048576.0).round(1),
      total_allocated_objects: gc[:total_allocated_objects],
      total_freed_objects: gc[:total_freed_objects],
      gc_count: gc[:count],
      major_gc_count: gc[:major_gc_count],
      minor_gc_count: gc[:minor_gc_count],
      malloc_increase_bytes: gc[:malloc_increase_bytes],
      oldmalloc_increase_bytes: gc[:oldmalloc_increase_bytes],
      count_objects: counts,
    }
  end

  # Expensive: single pass over ObjectSpace with each_object.
  # Collects per-class counts, sizes, and total memsize.
  # Can be slow or hang if DI probes are on methods in the iteration path.
  def self.object_stats(limit = 15)
    counts = Hash.new(0)
    sizes = Hash.new(0)
    total_memsize = 0
    ObjectSpace.each_object do |obj|
      begin
        klass = obj.class
        next unless klass
        sz = ObjectSpace.memsize_of(obj)
        counts[klass] += 1
        sizes[klass] += sz
        total_memsize += sz
      rescue NoMethodError, TypeError
        next
      end
    end
    {
      total_memsize: total_memsize,
      total_memsize_mb: (total_memsize / 1048576.0).round(1),
      by_count: counts.sort_by { |_k, v| -v }.first(limit).map { |k, v| {class_name: k.name || k.inspect, count: v} },
      by_size: sizes.sort_by { |_k, v| -v }.first(limit).map { |k, v| {class_name: k.name || k.inspect, bytes: v} },
    }
  end
end
