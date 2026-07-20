require 'rails_helper'
require_relative '../../lib/debugger_sessions_query'
require_relative '../../lib/datadog_session'

RSpec.describe DebuggerSessionsQuery do
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
        {'id' => 'sess-gobo', 'type' => 'session', 'attributes' => {
          'name' => 'debug gobo', 'num_probes' => 2, 'disabled' => false,
          'expires' => 0, 'created_by' => 'alice', 'created_at' => 1_760_000_000_000,
          'git_repositories' => ['github.com/p-datadog/gobo'],
          'service_names' => %w[gobo other]
        }},
        {'id' => 'sess-other', 'type' => 'session', 'attributes' => {
          'name' => 'debug other', 'num_probes' => 1, 'disabled' => false,
          'expires' => 0, 'service_names' => %w[other]
        }},
      ],
    }
  end

  describe '#call' do
    it 'returns only sessions that target the running service' do
      allow(session).to receive(:get_json).with('/api/ui/debugger/live-debugger/sessions')
        .and_return(response)
      result = build.call

      expect(result).to be_ok
      expect(result.sessions.map(&:id)).to eq(['sess-gobo'])
      first = result.sessions.first
      expect(first.name).to eq('debug gobo')
      expect(first.num_probes).to eq(2)
      expect(first.service_names).to eq(%w[gobo other])
    end

    it 'returns an empty list when no session targets the service' do
      allow(session).to receive(:get_json).and_return(
        {'data' => [{'id' => 'x', 'attributes' => {'service_names' => %w[other]}}]}
      )
      expect(build.call.sessions).to eq([])
    end

    it 'accepts a bare JSON:API array' do
      allow(session).to receive(:get_json).and_return(response['data'])
      expect(build.call.sessions.map(&:id)).to eq(['sess-gobo'])
    end

    it 'captures transport errors instead of raising' do
      allow(session).to receive(:get_json).and_raise(RuntimeError, 'no cookies staged')
      result = build.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged')
    end
  end
end
