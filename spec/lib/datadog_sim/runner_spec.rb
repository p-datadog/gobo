# frozen_string_literal: true

require 'rails_helper'
require 'datadog_sim/runner'

RSpec.describe DatadogSim::Runner do
  let(:options) do
    {
      language: 'java',
      service: 'test-service',
      env: 'test',
      version: '1.0',
      logger: Logger.new(File::NULL),
      components: { telemetry: true, remote_config: true, traces: true },
    }
  end

  subject(:runner) { described_class.new(options) }

  describe '#initialize' do
    it 'accepts all known languages' do
      DatadogSim::LANGUAGES.each_key do |lang|
        expect { described_class.new(options.merge(language: lang)) }.not_to raise_error
      end
    end

    it 'raises for unknown language' do
      expect { described_class.new(options.merge(language: 'cobol')) }
        .to raise_error(ArgumentError, /Unknown language/)
    end

    it 'generates a random runtime_id by default' do
      r1 = described_class.new(options)
      r2 = described_class.new(options)
      expect(r1.config[:runtime_id]).not_to eq(r2.config[:runtime_id])
    end

    it 'uses provided runtime_id' do
      runner = described_class.new(options.merge(runtime_id: 'fixed-id'))
      expect(runner.config[:runtime_id]).to eq('fixed-id')
    end

    it 'uses Java language profile values' do
      expect(runner.config[:rc_language]).to eq('java')
      expect(runner.config[:language_name]).to eq('jvm')
    end

    it 'uses default agent port 8126' do
      expect(runner.config[:agent_port]).to eq(8126)
    end

    it 'accepts custom agent port' do
      r = described_class.new(options.merge(agent_port: 18126))
      expect(r.config[:agent_port]).to eq(18126)
    end
  end

  describe 'component toggling' do
    it 'sends telemetry when enabled' do
      expect_any_instance_of(DatadogSim::Telemetry).to receive(:send_app_started)
      runner.startup
    end

    it 'skips telemetry when disabled' do
      r = described_class.new(options.merge(components: { telemetry: false, remote_config: false, traces: false }))
      expect_any_instance_of(DatadogSim::Telemetry).not_to receive(:send_app_started)
      r.startup
    end

    it 'sends traces when enabled' do
      expect_any_instance_of(DatadogSim::Traces).to receive(:send_trace)
      runner.startup
    end

    it 'skips traces when disabled' do
      r = described_class.new(options.merge(components: { telemetry: false, remote_config: false, traces: false }))
      expect_any_instance_of(DatadogSim::Traces).not_to receive(:send_trace)
      r.startup
    end
  end

  describe '#tick' do
    it 'polls RC when interval elapsed' do
      expect_any_instance_of(DatadogSim::RemoteConfig).to receive(:poll)
      runner.tick
    end

    it 'skips RC poll when interval not elapsed' do
      runner.tick  # first tick triggers poll and resets timer
      expect_any_instance_of(DatadogSim::RemoteConfig).not_to receive(:poll)
      runner.tick
    end
  end
end
