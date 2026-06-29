require 'json'
require 'net/http'
require 'uri'

# Runs the Live Debugger REDAPL service_config query against the Datadog beagle
# table API, reproducing the per-service environment lookup the web-ui
# RemoteEnablementOrgSettings page performs.
#
# The Datadog session cookies are read fresh from the local wclip web clipboard
# (/cookies-<env>.json) on every call and held only for the duration of the
# call. They are never written to disk, logged, or returned.
class RedaplQuery
  WCLIP_HOST = 'localhost'.freeze
  WCLIP_PORT = 8093
  BEAGLE_PATH = '/api/ui/beagle/table'.freeze
  CURRENT_USER_PATH = '/api/v1/legacy_current_user'.freeze
  LOGIN_PATH = '/account/login'.freeze
  QUERY_SOURCE = 'live-debugger'.freeze
  BASE_QUERY =
    'SELECT DISTINCT(service_name), language_name, service_env as env FROM service_config'.freeze
  USER_AGENT = (
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
  ).freeze

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
    open_timeout: 3, read_timeout: 10)
    @host = host
    @cookie_label = cookie_label
    @service = service
    @window_minutes = window_minutes
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def cookie_path
    "/cookies-#{@cookie_label}.json"
  end

  def query
    return BASE_QUERY unless @service

    "#{BASE_QUERY} WHERE service_name = '#{@service.to_s.gsub("'", "''")}'"
  end

  def call
    cookies = fetch_cookies
    csrf_token = fetch_csrf_token(cookies)
    response = run_query(cookies, csrf_token)
    result(rows: rows_from_response(response))
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(rows: [], error: nil)
    Result.new(
      rows: rows, error: error, query: query, host: @host,
      cookie_path: cookie_path, window_minutes: @window_minutes
    )
  end

  def fetch_cookies
    uri = URI::HTTP.build(host: WCLIP_HOST, port: WCLIP_PORT, path: cookie_path)
    _, body = http_get(uri)
    cookies = JSON.parse(body)
    raise "expected a JSON array of cookies at #{cookie_path}" unless cookies.is_a?(Array)
    raise "no cookies staged at #{cookie_path}" if cookies.empty?

    cookies
  end

  def cookie_header(cookies)
    cookies.map { |c| "#{c['name']}=#{c['value']}" }.join('; ')
  end

  # The web-ui landing page differs per host (staging embeds the token in HTML,
  # dogfood serves a JS shell), but both expose user.csrf_token via the
  # legacy_current_user JSON endpoint, so read it from there.
  def fetch_csrf_token(cookies)
    _, body = http_get(
      URI("https://#{@host}#{CURRENT_USER_PATH}"),
      'cookie' => cookie_header(cookies),
      'accept' => 'application/json',
      'user-agent' => USER_AGENT
    )
    token = JSON.parse(body)['csrf_token']
    raise "no csrf_token for #{@host} — session is not authenticated" if token.to_s.empty?

    token
  end

  def run_query(cookies, csrf_token)
    now_ms = (Time.now.to_f * 1000).to_i
    start_ms = now_ms - @window_minutes * 60 * 1000
    payload = {
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
    uri = URI("https://#{@host}#{BEAGLE_PATH}")
    request = Net::HTTP::Post.new(uri)
    request['content-type'] = 'application/json'
    request['accept'] = 'application/json'
    request['cookie'] = cookie_header(cookies)
    request['x-csrf-token'] = csrf_token
    request['user-agent'] = USER_AGENT
    request.body = JSON.generate(payload)

    response = perform(request, uri)
    unless response.is_a?(Net::HTTPSuccess)
      raise_for_response(response, BEAGLE_PATH)
    end

    JSON.parse(response.body)
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

  def http_get(uri, headers = {}, limit = 5)
    raise "too many redirects fetching #{uri}" if limit <= 0

    request = Net::HTTP::Get.new(uri)
    headers.each { |k, v| request[k] = v }
    response = perform(request, uri)

    case response
    when Net::HTTPSuccess
      [uri, response.body]
    when Net::HTTPRedirection
      location = response['location'].to_s
      raise "#{uri} redirected to #{location} — session is not authenticated" \
        if location.include?(LOGIN_PATH)

      http_get(URI.join(uri.to_s, location), headers, limit - 1)
    else
      raise_for_response(response, uri.to_s)
    end
  end

  def raise_for_response(response, where)
    if response.is_a?(Net::HTTPRedirection) &&
        response['location'].to_s.include?(LOGIN_PATH)
      raise "#{where} redirected to login — session is not authenticated"
    end

    raise "HTTP #{response.code} from #{where}: #{response.body.to_s[0, 200]}"
  end

  def perform(request, uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.is_a?(URI::HTTPS)
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout
    http.request(request)
  end
end
