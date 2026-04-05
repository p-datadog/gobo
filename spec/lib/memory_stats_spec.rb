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

  describe '.top_classes_by_count' do
    it 'returns an array of hashes with class_name and count' do
      result = described_class.top_classes_by_count(5)
      expect(result).to be_an(Array)
      expect(result.length).to be <= 5
      result.each do |row|
        expect(row).to have_key(:class_name)
        expect(row).to have_key(:count)
        expect(row[:count]).to be > 0
      end
    end

    it 'is sorted by count descending' do
      result = described_class.top_classes_by_count(5)
      counts = result.map { |r| r[:count] }
      expect(counts).to eq(counts.sort.reverse)
    end
  end

  describe '.top_classes_by_size' do
    it 'returns an array of hashes with class_name and bytes' do
      result = described_class.top_classes_by_size(5)
      expect(result).to be_an(Array)
      expect(result.length).to be <= 5
      result.each do |row|
        expect(row).to have_key(:class_name)
        expect(row).to have_key(:bytes)
      end
    end

    it 'is sorted by bytes descending' do
      result = described_class.top_classes_by_size(5)
      sizes = result.map { |r| r[:bytes] }
      expect(sizes).to eq(sizes.sort.reverse)
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
        :top_by_count, :top_by_size,
      )
    end

    it 'has rss_mb consistent with rss_bytes' do
      snap = described_class.snapshot
      expect(snap[:rss_mb]).to eq((snap[:rss_bytes] / 1048576.0).round(1))
    end
  end

  describe '.malloc_trim' do
    it 'returns an integer or nil (if not on glibc)' do
      result = described_class.malloc_trim
      expect(result).to be_nil.or be_a(Integer)
    end
  end
end
