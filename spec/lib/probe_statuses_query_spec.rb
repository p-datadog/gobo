require 'rails_helper'
require_relative '../../lib/probe_statuses_query'
require_relative '../../lib/datadog_session'

RSpec.describe ProbeStatusesQuery do
  let(:host) { 'dd.datad0g.com' }
  let(:session) do
    instance_double(DatadogSession, host: host, cookie_path: '/cookies-dogfood.json')
  end

  def build(**opts)
    described_class.new(
      host: host, cookie_label: 'dogfood', service: 'gobo', session: session, **opts
    )
  end

  let(:response) do
    {
      'data' => [
        {'id' => 'probe-1', 'type' => 'probe-statuses', 'attributes' => {
          'service' => 'gobo', 'status' => 'ACTIVE',
          'summary' => ['log probe at static_pages_controller.rb:30'],
          'lastCaptured' => '2026-07-20T15:00:00Z', 'probeUpdatedAt' => '2026-07-20T14:00:00Z',
          'stale' => false,
          'diagnostics' => [
            {'runtimeId' => 'rid-1', 'status' => 'INSTALLED', 'timestamp' => '2026-07-20T15:00:00Z'},
            {'runtimeId' => 'rid-2', 'status' => 'ERROR', 'timestamp' => '2026-07-20T15:00:01Z',
             'exception' => {'type' => 'NameError', 'message' => 'boom'}},
          ]
        }},
        {'id' => 'probe-other', 'type' => 'probe-statuses', 'attributes' => {
          'service' => 'other', 'status' => 'WAITING', 'summary' => []
        }},
      ],
    }
  end

  describe '#call' do
    it 'returns only probes for the running service with their status' do
      allow(session).to receive(:get_json).with('/api/ui/debugger/probe-statuses')
        .and_return(response)
      result = build.call

      expect(result).to be_ok
      expect(result.probes.map(&:id)).to eq(['probe-1'])
      probe = result.probes.first
      expect(probe.status).to eq('ACTIVE')
      expect(probe.summary).to eq(['log probe at static_pages_controller.rb:30'])
      expect(probe.last_captured).to eq('2026-07-20T15:00:00Z')
    end

    it 'parses per-runtime diagnostics including exceptions' do
      allow(session).to receive(:get_json).and_return(response)
      diagnostics = build.call.probes.first.diagnostics

      expect(diagnostics.map(&:runtime_id)).to eq(%w[rid-1 rid-2])
      expect(diagnostics.first.status).to eq('INSTALLED')
      expect(diagnostics.first.exception).to be_nil
      expect(diagnostics.last.exception).to eq(type: 'NameError', message: 'boom')
    end

    it 'returns an empty list when no probe is for the service' do
      allow(session).to receive(:get_json).and_return(
        {'data' => [{'id' => 'x', 'attributes' => {'service' => 'other', 'status' => 'ACTIVE'}}]}
      )
      expect(build.call.probes).to eq([])
    end

    it 'captures transport errors instead of raising' do
      allow(session).to receive(:get_json).and_raise(RuntimeError, 'no cookies staged')
      result = build.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged')
    end
  end
end
