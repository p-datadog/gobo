# frozen_string_literal: true

require 'rails_helper'
require 'datadog_sim/telemetry'

RSpec.describe DatadogSim::Telemetry do
  let(:config) do
    {
      language_name: 'jvm',
      runtime_name: 'OpenJDK',
      runtime_version: '17.0',
      tracer_version: '1.x',
      runtime_id: 'test-runtime-id',
      service: 'test-service',
      env: 'test',
      version: '1.0',
      agent_host: 'localhost',
      agent_port: 8126,
      git_repository_url: 'https://github.com/example/repo',
      git_commit_sha: 'abc123',
    }
  end

  let(:mock_http) { instance_double(Net::HTTP) }
  let(:ok_response) { instance_double(Net::HTTPResponse, code: '202') }

  before do
    allow(Net::HTTP).to receive(:new).and_return(mock_http)
    allow(mock_http).to receive(:request).and_return(ok_response)
  end

  subject(:telemetry) { described_class.new(config) }

  describe '#send_app_started' do
    it 'POSTs to the telemetry endpoint' do
      telemetry.send_app_started

      expect(mock_http).to have_received(:request) do |req|
        expect(req.path).to eq(DatadogSim::Telemetry::ENDPOINT)
        expect(req['DD-Telemetry-Request-Type']).to eq('app-started')
        expect(req['DD-Client-Library-Language']).to eq('jvm')
        body = JSON.parse(req.body)
        expect(body['request_type']).to eq('app-started')
        expect(body['runtime_id']).to eq('test-runtime-id')
        expect(body.dig('application', 'service_name')).to eq('test-service')
        expect(body.dig('payload', 'products', 'dynamic_instrumentation', 'enabled')).to be true
      end
    end

    it 'includes git metadata in configuration when set' do
      telemetry.send_app_started

      expect(mock_http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        config_names = body.dig('payload', 'configuration').map { |c| c['name'] }
        expect(config_names).to include('DD_GIT_REPOSITORY_URL', 'DD_GIT_COMMIT_SHA')
      end
    end

    it 'omits git metadata when not set' do
      config.delete(:git_repository_url)
      config.delete(:git_commit_sha)

      telemetry.send_app_started

      expect(mock_http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        expect(body.dig('payload', 'configuration')).to be_empty
      end
    end
  end

  describe '#send_heartbeat' do
    it 'POSTs app-heartbeat with empty payload' do
      telemetry.send_heartbeat

      expect(mock_http).to have_received(:request) do |req|
        expect(req['DD-Telemetry-Request-Type']).to eq('app-heartbeat')
        body = JSON.parse(req.body)
        expect(body['payload']).to eq({})
      end
    end

    it 'increments seq_id on each call' do
      seq_ids = []
      allow(mock_http).to receive(:request) do |req|
        seq_ids << JSON.parse(req.body)['seq_id']
        ok_response
      end

      telemetry.send_app_started
      telemetry.send_heartbeat
      telemetry.send_heartbeat

      expect(seq_ids).to eq([1, 2, 3])
    end
  end

  describe 'error handling' do
    it 'does not raise when agent is unreachable' do
      allow(mock_http).to receive(:request).and_raise(Errno::ECONNREFUSED)
      expect { telemetry.send_app_started }.not_to raise_error
    end
  end
end
