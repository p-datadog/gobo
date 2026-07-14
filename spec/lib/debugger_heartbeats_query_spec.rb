require 'rails_helper'
require_relative '../../lib/debugger_heartbeats_query'
require_relative '../../lib/datadog_session'

RSpec.describe DebuggerHeartbeatsQuery do
  let(:host) { 'dd.datad0g.com' }
  let(:session) do
    instance_double(DatadogSession, host: host, cookie_path: '/cookies-staging.json')
  end

  def build(**opts)
    described_class.new(
      host: host, cookie_label: 'staging', service: 'gobo', session: session, **opts
    )
  end

  let(:services_response) do
    [
      {'id' => 'gobo', 'type' => 'services',
       'attributes' => {'language' => 'ruby', 'lastSeen' => '2026-07-14T14:49:28.019Z'}},
      {'id' => 'other', 'type' => 'services', 'attributes' => {'lastSeen' => '2026-07-14T14:00:00Z'}},
    ]
  end

  let(:details_response) do
    {
      'data' => [
        {'id' => 'rid-1', 'type' => 'heartbeats', 'attributes' => {
          'serviceEnv' => 'staging', 'serviceVersion' => '5e97551',
          'datadogAgentId' => 'big-test-docker', 'lastSeen' => '2026-07-14T14:49:26.888Z',
          'tracerLanguage' => 'ruby',
          'tags' => ['env:staging', 'tracer_version:2.38.0-dev', 'language:ruby']
        }},
        {'id' => 'rid-2', 'type' => 'heartbeats', 'attributes' => {
          'serviceEnv' => 'staging', 'serviceVersion' => '5e97551',
          'datadogAgentId' => 'big-test-docker', 'lastSeen' => '2026-07-14T14:49:26.888Z',
          'tracerLanguage' => 'ruby',
          'tags' => ['tracer_version:2.38.0-dev']
        }},
        {'id' => 'rid-prod', 'type' => 'heartbeats', 'attributes' => {
          'serviceEnv' => 'prod', 'serviceVersion' => 'abc1234',
          'tags' => ['tracer_version:2.38.0-dev']
        }},
      ],
    }
  end

  describe '#details_path' do
    it 'targets the per-service heartbeats details route' do
      expect(build.details_path).to eq('/api/ui/debugger/heartbeats/details/gobo')
    end
  end

  describe '#call' do
    it 'returns one instance per heartbeat and the service lastSeen' do
      allow(session).to receive(:get_json).with('/api/ui/debugger/services').and_return(services_response)
      allow(session).to receive(:get_json)
        .with('/api/ui/debugger/heartbeats/details/gobo').and_return(details_response)

      result = build.call
      expect(result).to be_ok
      expect(result.last_seen).to eq('2026-07-14T14:49:28.019Z')
      expect(result.instances.size).to eq(3)
      first = result.instances.first
      expect(first.runtime_id).to eq('rid-1')
      expect(first.service_env).to eq('staging')
      expect(first.service_version).to eq('5e97551')
      expect(first.tracer_version).to eq('2.38.0-dev')
      expect(first.language).to eq('ruby')
      expect(first.agent_id).to eq('big-test-docker')
      expect(first.hostname).to be_nil
      expect(result.host).to eq(host)
      expect(result.cookie_path).to eq('/cookies-staging.json')
    end

    it 'filters instances to the requested env' do
      allow(session).to receive(:get_json).with('/api/ui/debugger/services').and_return(services_response)
      allow(session).to receive(:get_json)
        .with('/api/ui/debugger/heartbeats/details/gobo').and_return(details_response)

      result = build(env: 'staging').call
      expect(result.instances.map(&:runtime_id)).to eq(%w[rid-1 rid-2])
    end

    it 'accepts a bare-array details envelope' do
      allow(session).to receive(:get_json).with('/api/ui/debugger/services').and_return([])
      allow(session).to receive(:get_json)
        .with('/api/ui/debugger/heartbeats/details/gobo')
        .and_return(details_response['data'])
      expect(build.call.instances.size).to eq(3)
    end

    it 'captures any error into the result instead of raising' do
      allow(session).to receive(:get_json)
        .and_raise(RuntimeError, 'no cookies staged at /cookies-staging.json')
      result = build.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged at /cookies-staging.json')
      expect(result.instances).to be_empty
    end
  end
end
