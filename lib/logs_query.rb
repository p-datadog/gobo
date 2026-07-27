require_relative 'datadog_session'

# Queries the Datadog backend for logs, narrowed to a search query and time
# window. Uses the cookie-authenticated logs-analytics endpoint the Log
# Explorer UI itself calls:
#
#   POST /api/v1/logs-analytics/list?type=logs
#
# The CSRF token is sent both as the x-csrf-token header (via DatadogSession)
# and in the body as _authentication_token, which this endpoint requires. The
# public /api/v2/logs API is key-authenticated and rejects the wclip session,
# so this UI endpoint is the path available with staged cookies.
#
# Transport (wclip cookies, CSRF, HTTP) is handled by DatadogSession.
class LogsQuery
  LOGS_PATH = '/api/v1/logs-analytics/list?type=logs'.freeze
  DEFAULT_WINDOW_MINUTES = 30
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 1000

  Event = Struct.new(
    :id, :timestamp, :status, :service, :message, :tags, keyword_init: true
  ) do
    def to_h
      {
        id: id, timestamp: timestamp, status: status, service: service,
        message: message, tags: tags
      }
    end
  end

  Result = Struct.new(
    :events, :hit_count, :error, :query, :host, :cookie_path, :window_minutes,
    :limit, keyword_init: true
  ) do
    def ok?
      error.nil?
    end
  end

  def initialize(host:, cookie_label:, query:,
    window_minutes: DEFAULT_WINDOW_MINUTES, limit: DEFAULT_LIMIT,
    open_timeout: 3, read_timeout: 10, session: nil)
    @session = session || DatadogSession.new(
      host: host, cookie_label: cookie_label,
      open_timeout: open_timeout, read_timeout: read_timeout
    )
    @query = query
    @window_minutes = window_minutes
    @limit = limit.to_i.clamp(1, MAX_LIMIT)
  end

  attr_reader :query

  def cookie_path
    @session.cookie_path
  end

  def call
    response = @session.post_json(LOGS_PATH, payload, csrf_token: @session.csrf_token)
    result(events: events_from(response), hit_count: response['hitCount'])
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(events: [], hit_count: nil, error: nil)
    Result.new(
      events: events, hit_count: hit_count, error: error, query: @query,
      host: @session.host, cookie_path: cookie_path,
      window_minutes: @window_minutes, limit: @limit
    )
  end

  def payload
    now_ms = (Time.now.to_f * 1000).to_i
    start_ms = now_ms - @window_minutes * 60 * 1000
    {
      list: {
        columns: [],
        sorts: [{ field: { path: 'timestamp', order: 'desc' } }],
        limit: @limit,
        time: { from: start_ms, to: now_ms },
        search: { query: @query },
        includeEvents: true,
        computeCount: true,
        indexes: ['*'],
        executionInfo: { source: 'd' },
      },
      _authentication_token: @session.csrf_token,
    }
  end

  def events_from(response)
    (response.dig('result', 'events') || []).map do |row|
      event = row['event'] || {}
      Event.new(
        id: row['id'] || row['event_id'],
        timestamp: event['timestamp'],
        status: event['status'],
        service: event['service'],
        message: event['message'],
        tags: Array(event['tags'])
      )
    end
  end
end
