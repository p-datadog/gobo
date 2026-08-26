require 'rails_helper'
require_relative '../../lib/fake_tracer_version'

RSpec.describe FakeTracerVersion do
  describe '.apply' do
    let(:identity) { Datadog::Core::Environment::Identity }

    around do |example|
      original = identity.method(:gem_datadog_version)
      example.run
      identity.define_singleton_method(:gem_datadog_version, original)
    end

    it 'makes gem_datadog_version return the fake version' do
      described_class.apply('2.9.0')
      expect(identity.gem_datadog_version).to eq('2.9.0')
    end

    it 'makes gem_datadog_version_semver2 derive from the fake version' do
      described_class.apply('2.40.0.dev')
      expect(identity.gem_datadog_version_semver2).to eq('2.40.0-dev')
    end

    it 'returns the applied version' do
      expect(described_class.apply('3.1.4')).to eq('3.1.4')
    end

    it 'accepts a plain three-part version' do
      expect { described_class.apply('2.11.0') }.not_to raise_error
    end

    it 'raises on an empty string' do
      expect { described_class.apply('') }.to raise_error(described_class::Error)
    end

    it 'raises on a non-string' do
      expect { described_class.apply(290) }.to raise_error(described_class::Error)
    end

    it 'raises on a malformed version' do
      expect { described_class.apply('2.9') }.to raise_error(described_class::Error)
    end
  end
end
