require 'rails_helper'
require_relative '../../lib/live_service_instances_query'
require_relative '../../lib/datadog_session'

RSpec.describe LiveServiceInstancesQuery do
  let(:host) { 'dd.datad0g.com' }

  def build(**opts)
    described_class.new(host: host, cookie_label: 'staging', service: 'gobo', **opts)
  end

  describe '#cookie_path' do
    it 'derives the wclip path from the environment label' do
      expect(build.cookie_path).to eq('/cookies-staging.json')
      expect(described_class.new(host: host, cookie_label: 'dogfood', service: 'gobo').cookie_path)
        .to eq('/cookies-dogfood.json')
    end
  end

  describe '#endpoint' do
    it 'includes only service_name when no env is given' do
      expect(build.endpoint).to eq('/api/unstable/live-service-instances?service_name=gobo')
    end

    it 'includes service_env and url-encodes params when env is given' do
      endpoint = described_class.new(
        host: host, cookie_label: 'staging', service: 'go bo', env: 'staging'
      ).endpoint
      expect(endpoint).to eq(
        '/api/unstable/live-service-instances?service_name=go+bo&service_env=staging'
      )
    end
  end

  describe '#call' do
    let(:session) do
      instance_double(DatadogSession, host: host, cookie_path: '/cookies-staging.json')
    end

    subject(:query) { build(env: 'staging', session: session) }

    let(:api_response) do
      {
        'data' => {
          'id' => 'gobo',
          'type' => 'live_service_instances',
          'attributes' => {
            'active_service_instances' => [
              {
                'runtime_id' => 'rid-1',
                'hostname' => 'host-a',
                'service_env' => 'staging',
                'service_version' => '7cd00b1',
                'client_library_version' => '2.20.0',
                'agent_hostname' => 'agent-a',
                'agent_version' => '7.55.0',
                'di_enabled' => true,
                'system_probe_enabled' => false,
                'remote_config_products' => %w[LIVE_DEBUGGING LIVE_DEBUGGING_SYMBOL_DB],
                'language_name' => 'ruby',
                'last_seen' => 1_700_000_000,
              },
            ],
            'inactive_service_instances' => [
              {'runtime_id' => 'rid-0', 'hostname' => 'host-z', 'service_env' => 'staging'},
            ],
          },
        },
      }
    end

    it 'returns parsed active and inactive instances on success' do
      allow(session).to receive(:get_json).and_return(api_response)
      result = query.call
      expect(result).to be_ok
      expect(result.active.size).to eq(1)
      active = result.active.first
      expect(active.runtime_id).to eq('rid-1')
      expect(active.di_enabled).to be(true)
      expect(active.client_library_version).to eq('2.20.0')
      expect(active.remote_config_products).to eq(%w[LIVE_DEBUGGING LIVE_DEBUGGING_SYMBOL_DB])
      expect(result.inactive.map(&:runtime_id)).to eq(['rid-0'])
      expect(result.endpoint).to include('service_name=gobo')
      expect(result.endpoint).to include('service_env=staging')
      expect(result.host).to eq(host)
      expect(result.cookie_path).to eq('/cookies-staging.json')
      expect(result.service).to eq('gobo')
      expect(result.env).to eq('staging')
    end

    it 'requests the live-service-instances endpoint for the service and env' do
      expect(session).to receive(:get_json)
        .with('/api/unstable/live-service-instances?service_name=gobo&service_env=staging')
        .and_return('data' => {'attributes' => {}})
      query.call
    end

    it 'returns empty instance sets when the backend reports none' do
      allow(session).to receive(:get_json).and_return(
        'data' => {'attributes' => {
          'active_service_instances' => [], 'inactive_service_instances' => []
        }}
      )
      result = query.call
      expect(result).to be_ok
      expect(result.active).to be_empty
      expect(result.inactive).to be_empty
    end

    it 'captures any error into the result instead of raising' do
      allow(session).to receive(:get_json)
        .and_raise(RuntimeError, 'no cookies staged at /cookies-staging.json')
      result = query.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged at /cookies-staging.json')
      expect(result.active).to be_empty
      expect(result.inactive).to be_empty
    end
  end
end
