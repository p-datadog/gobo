# frozen_string_literal: true

require 'rails_helper'
require 'datadog_sim/remote_config'

RSpec.describe DatadogSim::RemoteConfig do
  let(:config) do
    {
      runtime_id: 'test-runtime-id',
      rc_language: 'java',
      tracer_version: '1.x',
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
  let(:empty_response) { instance_double(Net::HTTPResponse, code: '200', body: '{}') }
  let(:on_config) { instance_double(Proc, call: nil) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(mock_http)
    allow(mock_http).to receive(:request).and_return(empty_response)
  end

  subject(:rc) { described_class.new(config, on_config: on_config) }

  describe '#poll' do
    it 'POSTs to the RC endpoint with correct products and capabilities' do
      rc.poll

      expect(mock_http).to have_received(:request) do |req|
        expect(req.path).to eq(DatadogSim::RemoteConfig::ENDPOINT)
        body = JSON.parse(req.body)
        expect(body.dig('client', 'products')).to include('APM_TRACING', 'LIVE_DEBUGGING', 'LIVE_DEBUGGING_SYMBOL_DB')
        expect(body.dig('client', 'is_tracer')).to be true
        expect(body.dig('client', 'capabilities')).to eq(DatadogSim::RemoteConfig::CAPABILITIES)
        expect(body.dig('client', 'client_tracer', 'runtime_id')).to eq('test-runtime-id')
        expect(body.dig('client', 'client_tracer', 'language')).to eq('java')
      end
    end

    it 'includes git tags in client_tracer when set' do
      rc.poll

      expect(mock_http).to have_received(:request) do |req|
        body = JSON.parse(req.body)
        tags = body.dig('client', 'client_tracer', 'tags')
        expect(tags).to include('git.repository_url:https://github.com/example/repo')
        expect(tags).to include('git.commit.sha:abc123')
      end
    end

    it 'calls on_config when upload_symbols config received' do
      symdb_config = Base64.strict_encode64({ upload_symbols: true }.to_json)
      response_body = {
        client_configs: ['datadog/2/LIVE_DEBUGGING_SYMBOL_DB/symdb/config'],
        target_files: [{
          path: 'datadog/2/LIVE_DEBUGGING_SYMBOL_DB/symdb/config',
          raw: symdb_config,
        }],
      }.to_json
      allow(mock_http).to receive(:request)
        .and_return(instance_double(Net::HTTPResponse, code: '200', body: response_body))

      rc.poll

      expect(on_config).to have_received(:call).with({ upload_symbols: true })
    end

    it 'does not call on_config for empty response' do
      rc.poll
      expect(on_config).not_to have_received(:call)
    end

    it 'does not call on_config when client_configs is absent (backend not targeting this instance yet)' do
      # Normal state before backend selects this instance — client_configs is nil
      response_body = { roots: ['eyJ...'] }.to_json
      allow(mock_http).to receive(:request)
        .and_return(instance_double(Net::HTTPResponse, code: '200', body: response_body))

      expect { rc.poll }.not_to raise_error
      expect(on_config).not_to have_received(:call)
    end

    it 'accumulates root_version across multiple polls (TUF bootstrap phase)' do
      # The agent sends roots in batches. root_version must be incremented
      # (not replaced) on each response so we converge to the latest version.
      # e.g. poll 1 returns 15 roots → root_version 1+15=16
      #      poll 2 returns 1 root  → root_version 16+1=17  (not 1!)
      first_response = { roots: Array.new(15, 'eyJhIjoxfQ==') }.to_json
      second_response = { roots: ['eyJiIjoyfQ=='] }.to_json

      allow(mock_http).to receive(:request)
        .and_return(
          instance_double(Net::HTTPResponse, code: '200', body: first_response),
          instance_double(Net::HTTPResponse, code: '200', body: second_response),
          instance_double(Net::HTTPResponse, code: '200', body: '{}'),
        )

      rc.poll  # gets 15 roots, root_version → 1+15=16
      rc.poll  # gets 1 root,  root_version → 16+1=17

      expect(mock_http).to receive(:request) do |req|
        body = JSON.parse(req.body)
        expect(body.dig('client', 'state', 'root_version')).to eq(17)
        instance_double(Net::HTTPResponse, code: '200', body: '{}')
      end
      rc.poll
    end

    it 'advances targets_version and backend_client_state from signed targets' do
      opaque = 'abc123opaque'
      targets_json = Base64.strict_encode64({
        'signed' => { 'version' => 42, 'custom' => { 'opaque_backend_state' => opaque } }
      }.to_json)
      response_body = { 'targets' => targets_json }.to_json
      allow(mock_http).to receive(:request)
        .and_return(
          instance_double(Net::HTTPResponse, code: '200', body: response_body),
          instance_double(Net::HTTPResponse, code: '200', body: '{}'),
        )

      rc.poll  # processes targets

      expect(mock_http).to receive(:request) do |req|
        body = JSON.parse(req.body)
        expect(body.dig('client', 'state', 'targets_version')).to eq(42)
        expect(body.dig('client', 'state', 'backend_client_state')).to eq(opaque)
        instance_double(Net::HTTPResponse, code: '200', body: '{}')
      end
      rc.poll
    end

    it 'does not raise when agent is unreachable' do
      allow(mock_http).to receive(:request).and_raise(Errno::ECONNREFUSED)
      expect { rc.poll }.not_to raise_error
    end
  end
end
