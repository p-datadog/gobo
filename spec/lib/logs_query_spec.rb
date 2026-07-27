require 'rails_helper'
require_relative '../../lib/logs_query'
require_relative '../../lib/datadog_session'

RSpec.describe LogsQuery do
  let(:host) { 'squirrel.datadoghq.com' }
  let(:session) do
    instance_double(
      DatadogSession, host: host, cookie_path: '/cookies-dogfood.json',
      csrf_token: 'deadbeef'
    )
  end

  subject(:logs) do
    described_class.new(
      host: host, cookie_label: 'dogfood', query: 'service:gobo',
      window_minutes: 15, limit: 10, session: session
    )
  end

  describe '#cookie_path' do
    it 'delegates to the session' do
      expect(logs.cookie_path).to eq('/cookies-dogfood.json')
    end
  end

  let(:logs_response) do
    {
      'hitCount' => 2149,
      'result' => {
        'events' => [
          {
            'id' => 'AQ',
            'event' => {
              'timestamp' => '2026-07-27T20:46:43.601Z',
              'status' => 'info',
              'service' => 'gobo',
              'message' => 'In static_pages_controller.rb, line 30',
              'tags' => ['source:dd_debugger', 'service:gobo', 'env:production'],
            },
          },
          {
            'event_id' => 'BQ',
            'event' => {
              'timestamp' => '2026-07-27T20:46:42.000Z',
              'status' => 'error',
              'service' => 'gobo',
              'message' => 'boom',
              'tags' => [],
            },
          },
        ],
      },
    }
  end

  describe '#call' do
    it 'posts the list query to the logs-analytics endpoint with the auth token in the body' do
      expect(session).to receive(:post_json).with(
        described_class::LOGS_PATH,
        hash_including(
          list: hash_including(
            limit: 10,
            search: { query: 'service:gobo' },
            indexes: ['*'],
            includeEvents: true,
            sorts: [{ field: { path: 'timestamp', order: 'desc' } }]
          ),
          _authentication_token: 'deadbeef'
        ),
        csrf_token: 'deadbeef'
      ).and_return('result' => { 'events' => [] })
      logs.call
    end

    it 'sends a time window derived from window_minutes' do
      now_ms = 1_785_000_000_000
      allow(Time).to receive(:now).and_return(instance_double(Time, to_f: now_ms / 1000.0))
      captured = nil
      allow(session).to receive(:post_json) do |_path, payload, **_kw|
        captured = payload
        { 'result' => { 'events' => [] } }
      end
      logs.call
      time = captured[:list][:time]
      expect(time[:to]).to eq(now_ms)
      expect(time[:from]).to eq(now_ms - 15 * 60 * 1000)
    end

    it 'parses events and the hit count on success' do
      allow(session).to receive(:post_json).and_return(logs_response)
      result = logs.call
      expect(result).to be_ok
      expect(result.hit_count).to eq(2149)
      expect(result.events.length).to eq(2)
      first = result.events.first
      expect(first.id).to eq('AQ')
      expect(first.timestamp).to eq('2026-07-27T20:46:43.601Z')
      expect(first.status).to eq('info')
      expect(first.service).to eq('gobo')
      expect(first.message).to eq('In static_pages_controller.rb, line 30')
      expect(first.tags).to include('source:dd_debugger')
      expect(result.events.last.id).to eq('BQ')
      expect(result.host).to eq(host)
      expect(result.cookie_path).to eq('/cookies-dogfood.json')
      expect(result.window_minutes).to eq(15)
      expect(result.limit).to eq(10)
    end

    it 'returns an empty event set when the backend reports none' do
      allow(session).to receive(:post_json).and_return('result' => { 'events' => [] })
      result = logs.call
      expect(result).to be_ok
      expect(result.events).to be_empty
    end

    it 'captures any error into the result instead of raising' do
      allow(session).to receive(:csrf_token)
        .and_raise(RuntimeError, 'no cookies staged at /cookies-dogfood.json')
      result = logs.call
      expect(result).not_to be_ok
      expect(result.error).to eq('RuntimeError: no cookies staged at /cookies-dogfood.json')
      expect(result.events).to be_empty
    end
  end

  describe 'limit clamping' do
    it 'clamps above the maximum' do
      q = described_class.new(host: host, cookie_label: 'dogfood', query: '*',
        limit: 99_999, session: session)
      allow(session).to receive(:post_json).and_return('result' => { 'events' => [] })
      expect(q.call.limit).to eq(described_class::MAX_LIMIT)
    end

    it 'clamps a non-positive limit up to 1' do
      q = described_class.new(host: host, cookie_label: 'dogfood', query: '*',
        limit: 0, session: session)
      allow(session).to receive(:post_json).and_return('result' => { 'events' => [] })
      expect(q.call.limit).to eq(1)
    end
  end
end
