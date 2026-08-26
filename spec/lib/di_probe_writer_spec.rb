require 'rails_helper'
require_relative '../../lib/di_probe_writer'
require_relative '../../lib/datadog_session'

RSpec.describe DIProbeWriter do
  let(:host) { 'dd.datad0g.com' }
  let(:session) do
    instance_double(DatadogSession, host: host, cookie_path: '/cookies-staging.json',
      csrf_token: 'tok')
  end

  def build(**opts)
    described_class.new(host: host, cookie_label: 'staging', service: 'gobo',
      env: 'staging', session: session, **opts)
  end

  describe '#create' do
    it 'posts a google/jsonapi di_log_probe body targeting the service+env' do
      allow(session).to receive(:post_json) do |path, body, csrf_token:|
        expect(path).to eq('/api/ui/remote_config/products/live_debugging/probes/log/')
        expect(csrf_token).to eq('tok')
        data = body.fetch('data')
        expect(data.fetch('type')).to eq('di_log_probe')
        attrs = data.fetch('attributes')
        expect(attrs.fetch('metadata')).to eq(
          'service_name' => 'gobo',
          'type' => 'LOG_PROBE',
          'enablement' => {
            'queries' => [
              { 'text' => 'env:staging',
                'tags' => [{ 'key' => 'env',
                             'values' => [{ 'value' => 'staging', 'is_excluded' => false }] }] },
            ],
          }
        )
        probe = attrs.fetch('probe')
        expect(probe.fetch('where')).to eq('type_name' => 'DebuggerTestController', 'method_name' => 'calculate')
        expect(probe.fetch('language')).to eq('ruby')
        expect(probe.fetch('capture_snapshot')).to eq(true)
        expect(probe.fetch('segments')).to eq([])
        { 'data' => { 'id' => data.fetch('id'), 'type' => 'di_log_probe' } }
      end

      result = build.create(type_name: 'DebuggerTestController', method_name: 'calculate')
      expect(result).to be_ok
      expect(result.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'returns the server-assigned id when the response carries one' do
      allow(session).to receive(:post_json)
        .and_return('data' => { 'id' => 'server-uuid', 'type' => 'di_log_probe' })
      result = build.create(type_name: 'C', method_name: 'm')
      expect(result.id).to eq('server-uuid')
    end

    it 'propagates errors as class: message' do
      allow(session).to receive(:post_json)
        .and_raise(StandardError.new('boom'))
      result = build.create(type_name: 'C', method_name: 'm')
      expect(result).not_to be_ok
      expect(result.error).to eq('StandardError: boom')
    end
  end

  describe '#delete' do
    it 'DELETEs the probe id under the log probes path' do
      allow(session).to receive(:delete_json) do |path, csrf_token:|
        expect(path).to eq('/api/ui/remote_config/products/live_debugging/probes/log/abc-123')
        expect(csrf_token).to eq('tok')
        ''
      end
      result = build.delete('abc-123')
      expect(result).to be_ok
      expect(result.id).to eq('abc-123')
    end

    it 'propagates errors as class: message' do
      allow(session).to receive(:delete_json).and_raise(StandardError.new('nope'))
      result = build.delete('abc-123')
      expect(result).not_to be_ok
      expect(result.error).to eq('StandardError: nope')
    end
  end

  describe '#list' do
    let(:response) do
      { 'data' => [
        { 'id' => 'p1', 'type' => 'di_log_probe', 'attributes' => {
          'metadata' => { 'service_name' => 'gobo',
            'enablement' => { 'queries' => [{ 'tags' => [{ 'key' => 'env',
              'values' => [{ 'value' => 'staging' }] }] }] } },
          'probe' => { 'where' => { 'type_name' => 'DebuggerTestController', 'method_name' => 'calculate' },
            'language' => 'ruby', 'capture_snapshot' => true } } },
        { 'id' => 'p2', 'type' => 'di_log_probe', 'attributes' => {
          'metadata' => { 'service_name' => 'other',
            'enablement' => { 'queries' => [] } },
          'probe' => { 'where' => {} } } },
      ] }
    end

    it 'returns only probes for the running service' do
      allow(session).to receive(:get_json)
        .with('/api/ui/remote_config/products/live_debugging/probes/')
        .and_return(response)
      result = build.list
      expect(result).to be_ok
      expect(result.probes.map(&:id)).to eq(['p1'])
      probe = result.probes.first
      expect(probe.where).to eq('DebuggerTestController#calculate')
      expect(probe.env).to eq('staging')
      expect(probe.capture_snapshot).to eq(true)
    end

    it 'propagates errors as class: message' do
      allow(session).to receive(:get_json).and_raise(StandardError.new('x'))
      expect(build.list.error).to eq('StandardError: x')
    end
  end
end
