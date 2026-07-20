require 'rails_helper'
require_relative '../../lib/remote_enablement_query'
require_relative '../../lib/datadog_session'

RSpec.describe RemoteEnablementQuery do
  let(:host) { 'dd.datad0g.com' }
  let(:session) do
    instance_double(DatadogSession, host: host, cookie_path: '/cookies-dogfood.json')
  end

  def build(**opts)
    described_class.new(
      host: host, cookie_label: 'dogfood', service: 'gobo', env: 'production',
      session: session, **opts
    )
  end

  let(:response) do
    {
      'data' => [
        {'id' => 'gobo/production/ruby', 'type' => 'debugger_config', 'attributes' => {
          'service' => 'gobo', 'env' => 'production', 'config_exists' => true,
          'dynamic_instrumentation_enabled' => true, 'language' => 'ruby',
          'client_library_version' => '2.39.0', 'modified_time' => 1_760_000_000
        }},
        {'id' => 'gobo/production/go', 'type' => 'debugger_config', 'attributes' => {
          'service' => 'gobo', 'env' => 'production', 'config_exists' => true,
          'dynamic_instrumentation_enabled' => false, 'language' => 'go',
          'client_library_version' => '2.6.0', 'modified_time' => 1_760_000_100
        }},
      ],
    }
  end

  describe '#path' do
    it 'targets the apm_tracing debugger_configs route for the service and env' do
      expect(build.path).to eq(
        '/api/unstable/remote_config/products/apm_tracing/debugger_configs/envs/production/services/gobo'
      )
    end
  end

  describe '#call' do
    it 'returns one config per row with the stored DI enable state' do
      allow(session).to receive(:get_json).with(build.path).and_return(response)
      result = build.call

      expect(result).to be_ok
      expect(result.configs.map(&:language)).to eq(%w[ruby go])
      expect(result.configs.map(&:dynamic_instrumentation_enabled)).to eq([true, false])
      expect(result.configs.first.client_library_version).to eq('2.39.0')
      expect(result.configs.first.config_exists).to be(true)
      expect(result.configs.first.modified_time).to eq(1_760_000_000)
    end

    it 'accepts a bare JSON:API array as well as a data envelope' do
      allow(session).to receive(:get_json).and_return(response['data'])
      expect(build.call.configs.size).to eq(2)
    end

    it 'returns an empty config list when the service has no config' do
      allow(session).to receive(:get_json).and_return({'data' => []})
      result = build.call
      expect(result).to be_ok
      expect(result.configs).to eq([])
    end

    it 'captures transport errors in the result instead of raising' do
      allow(session).to receive(:get_json).and_raise(RuntimeError, 'no cookies staged')
      result = build.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged')
      expect(result.host).to eq(host)
      expect(result.cookie_path).to eq('/cookies-dogfood.json')
    end
  end
end
