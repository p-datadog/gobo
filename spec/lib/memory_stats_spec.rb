require 'spec_helper'
require_relative '../../lib/memory_stats'

RSpec.describe MemoryStats do
  describe '.rss_bytes' do
    it 'returns a positive integer' do
      rss = described_class.rss_bytes
      expect(rss).to be_a(Integer)
      expect(rss).to be > 0
    end
  end

  describe '.heap_live_slots' do
    it 'returns a positive integer' do
      slots = described_class.heap_live_slots
      expect(slots).to be_a(Integer)
      expect(slots).to be > 0
    end
  end

  describe '.snapshot' do
    it 'returns a hash with all expected keys' do
      snap = described_class.snapshot
      expect(snap).to include(
        :rss_bytes, :rss_mb, :heap_live_slots, :heap_free_slots,
        :heap_live_estimate_mb, :total_allocated_objects, :total_freed_objects,
        :gc_count, :major_gc_count, :minor_gc_count,
        :malloc_increase_bytes, :oldmalloc_increase_bytes,
        :count_objects,
      )
    end

    it 'does not include expensive object_stats fields' do
      snap = described_class.snapshot
      expect(snap).not_to have_key(:top_by_count)
      expect(snap).not_to have_key(:top_by_size)
      expect(snap).not_to have_key(:heap_measured_bytes)
    end

    it 'has rss_mb consistent with rss_bytes' do
      snap = described_class.snapshot
      expect(snap[:rss_mb]).to eq((snap[:rss_bytes] / 1048576.0).round(1))
    end

    it 'includes count_objects with T_STRING' do
      snap = described_class.snapshot
      expect(snap[:count_objects]).to have_key(:T_STRING)
      expect(snap[:count_objects][:T_STRING]).to be > 0
    end
  end

  describe '.object_stats' do
    it 'returns total_memsize, by_count, and by_size' do
      result = described_class.object_stats(5)
      expect(result).to have_key(:total_memsize)
      expect(result[:total_memsize]).to be > 0
      expect(result).to have_key(:total_memsize_mb)
      expect(result[:by_count]).to be_an(Array)
      expect(result[:by_size]).to be_an(Array)
    end

    it 'by_count entries have class_name and count, sorted descending' do
      result = described_class.object_stats(5)
      counts = result[:by_count].map { |r| r[:count] }
      expect(counts).to eq(counts.sort.reverse)
      result[:by_count].each do |row|
        expect(row).to have_key(:class_name)
        expect(row[:count]).to be > 0
      end
    end

    it 'by_size entries have class_name and bytes, sorted descending' do
      result = described_class.object_stats(5)
      sizes = result[:by_size].map { |r| r[:bytes] }
      expect(sizes).to eq(sizes.sort.reverse)
      result[:by_size].each do |row|
        expect(row).to have_key(:class_name)
        expect(row).to have_key(:bytes)
      end
    end
  end

  describe '.malloc_trim' do
    it 'returns an integer or nil (if not on glibc)' do
      result = described_class.malloc_trim
      expect(result).to be_nil.or be_a(Integer)
    end
  end
end
