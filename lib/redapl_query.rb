require_relative 'datadog_session'

# Runs the Live Debugger REDAPL service_config query against the Datadog beagle
# table API, reproducing the per-service environment lookup the web-ui
# RemoteEnablementOrgSettings page performs.
#
# Transport (wclip cookies, CSRF, HTTP) is handled by DatadogSession.
class RedaplQuery
  BEAGLE_PATH = '/api/ui/beagle/table'.freeze
  QUERY_SOURCE = 'live-debugger'.freeze
  BASE_QUERY =
    'SELECT DISTINCT(service_name), language_name, service_env as env FROM service_config'.freeze

  Row = Struct.new(:service_name, :language_name, :env, keyword_init: true)

  Result = Struct.new(
    :rows, :error, :query, :host, :cookie_path, :window_minutes,
    keyword_init: true
  ) do
    def ok?
      error.nil?
    end
  end

  def initialize(host:, cookie_label:, service: nil, window_minutes: 10,
    open_timeout: 3, read_timeout: 10, session: nil)
    @session = session || DatadogSession.new(
      host: host, cookie_label: cookie_label,
      open_timeout: open_timeout, read_timeout: read_timeout
    )
    @service = service
    @window_minutes = window_minutes
  end

  def cookie_path
    @session.cookie_path
  end

  def query
    return BASE_QUERY unless @service

    "#{BASE_QUERY} WHERE service_name = '#{@service.to_s.gsub("'", "''")}'"
  end

  def call
    response = @session.post_json(BEAGLE_PATH, query_payload, csrf_token: @session.csrf_token)
    result(rows: rows_from_response(response))
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(rows: [], error: nil)
    Result.new(
      rows: rows, error: error, query: query, host: @session.host,
      cookie_path: cookie_path, window_minutes: @window_minutes
    )
  end

  def query_payload
    now_ms = (Time.now.to_f * 1000).to_i
    start_ms = now_ms - @window_minutes * 60 * 1000
    {
      data: {
        type: 'ddsql_table_request',
        attributes: {
          query: query,
          default_start: start_ms,
          default_end: now_ms,
          default_interval: now_ms - start_ms,
          source: QUERY_SOURCE,
        },
      },
    }
  end

  def rows_from_response(response)
    data = response['data'] || []
    return [] if data.empty?

    columns = data.first.dig('attributes', 'columns') || []
    names = columns.map { |c| c['name'] }
    values = columns.map { |c| c['values'] || [] }
    height = values.map(&:length).max || 0
    index = names.each_with_index.to_h
    env_col = index['env'] || index['service_env']

    (0...height).map do |r|
      Row.new(
        service_name: cell(values, index['service_name'], r),
        language_name: cell(values, index['language_name'], r),
        env: cell(values, env_col, r)
      )
    end
  end

  def cell(values, col, row)
    return nil if col.nil?

    column = values[col] || []
    row < column.length ? column[row] : nil
  end
end
