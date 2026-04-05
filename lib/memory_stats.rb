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

  def self.top_classes_by_count(limit = 15)
    counts = Hash.new(0)
    ObjectSpace.each_object do |obj|
      klass = begin; obj.class; rescue NoMethodError; nil; end
      counts[klass] += 1 if klass
    end
    counts.sort_by { |_k, v| -v }.first(limit).map { |k, v| {class_name: k.name || k.inspect, count: v} }
  end

  def self.top_classes_by_size(limit = 15)
    sizes = Hash.new(0)
    ObjectSpace.each_object do |obj|
      klass = begin; obj.class; rescue NoMethodError; nil; end
      sizes[klass] += ObjectSpace.memsize_of(obj) if klass
    end
    sizes.sort_by { |_k, v| -v }.first(limit).map { |k, v| {class_name: k.name || k.inspect, bytes: v} }
  end

  def self.snapshot
    gc = GC.stat
    rss = rss_bytes

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
      top_by_count: top_classes_by_count,
      top_by_size: top_classes_by_size,
    }
  end
end
