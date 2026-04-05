require 'spec_helper'
require_relative '../../lib/tracer_resolver'

RSpec.describe TracerResolver do
  describe '.resolve' do
    it 'resolves branch shorthand' do
      expect(described_class.resolve('branch:my-feature')).to eq(
        'git+https://github.com/DataDog/dd-trace-rb@my-feature'
      )
    end

    it 'resolves sha shorthand' do
      expect(described_class.resolve('sha:abc1234')).to eq(
        'git+https://github.com/DataDog/dd-trace-rb@abc1234'
      )
    end

    it 'resolves fork shorthand' do
      expect(described_class.resolve('fork:myuser/my-branch')).to eq(
        'git+https://github.com/myuser/dd-trace-rb@my-branch'
      )
    end

    it 'resolves bare master to branch URL' do
      expect(described_class.resolve('master')).to eq(
        'git+https://github.com/DataDog/dd-trace-rb@master'
      )
    end

    it 'returns nil for --reset' do
      expect(described_class.resolve('--reset')).to be_nil
    end

    it 'passes through version strings' do
      expect(described_class.resolve('2.12.0')).to eq('2.12.0')
    end

    it 'passes through local paths' do
      expect(described_class.resolve('/home/user/dd-trace-rb')).to eq('/home/user/dd-trace-rb')
    end

    it 'passes through full git URLs' do
      url = 'git+https://github.com/DataDog/dd-trace-rb@master'
      expect(described_class.resolve(url)).to eq(url)
    end
  end
end
