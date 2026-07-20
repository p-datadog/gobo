require 'rails_helper'
require 'tmpdir'
require_relative '../../lib/runtime_id_registry'

RSpec.describe RuntimeIdRegistry do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  attr_reader :dir

  describe '#record' do
    it 'writes the runtime id to a file named after the pid' do
      described_class.new(dir).record(runtime_id: 'rid-abc', pid: 4242)
      expect(File.read(File.join(dir, '4242'))).to eq('rid-abc')
    end

    it 'creates the directory if it does not exist' do
      nested = File.join(dir, 'di_runtime_ids')
      described_class.new(nested).record(runtime_id: 'rid-1', pid: 1)
      expect(File.read(File.join(nested, '1'))).to eq('rid-1')
    end

    it 'does not write a file for a blank runtime id' do
      described_class.new(dir).record(runtime_id: '  ', pid: 7)
      expect(File.exist?(File.join(dir, '7'))).to be(false)
    end

    it 'does not write a file for a nil runtime id' do
      described_class.new(dir).record(runtime_id: nil, pid: 7)
      expect(File.exist?(File.join(dir, '7'))).to be(false)
    end
  end

  describe '#live_runtime_ids' do
    def checker(*alive_pids)
      ->(pid) { alive_pids.include?(pid) }
    end

    it 'returns runtime ids of pids reported alive' do
      registry = described_class.new(dir, process_checker: checker(1, 2))
      registry.record(runtime_id: 'rid-1', pid: 1)
      registry.record(runtime_id: 'rid-2', pid: 2)

      expect(described_class.new(dir, process_checker: checker(1, 2)).live_runtime_ids)
        .to contain_exactly('rid-1', 'rid-2')
    end

    it 'omits and prunes files for dead pids' do
      described_class.new(dir).record(runtime_id: 'rid-alive', pid: 1)
      described_class.new(dir).record(runtime_id: 'rid-dead', pid: 2)

      result = described_class.new(dir, process_checker: checker(1)).live_runtime_ids

      expect(result).to contain_exactly('rid-alive')
      expect(File.exist?(File.join(dir, '2'))).to be(false)
      expect(File.exist?(File.join(dir, '1'))).to be(true)
    end

    it 'returns an empty set when the directory does not exist' do
      registry = described_class.new(File.join(dir, 'missing'))
      expect(registry.live_runtime_ids).to be_empty
    end

    it 'ignores non-pid filenames' do
      File.write(File.join(dir, 'not-a-pid'), 'rid-x')
      described_class.new(dir).record(runtime_id: 'rid-1', pid: 1)

      expect(described_class.new(dir, process_checker: checker(1)).live_runtime_ids)
        .to contain_exactly('rid-1')
    end
  end
end
