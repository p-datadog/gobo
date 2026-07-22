require 'json'
require 'net/http'
require 'uri'

# Authenticated Datadog web session backed by cookies staged in the local wclip
# web clipboard (/cookies-<label>.json). Shared transport for the DI Status
# diagnostics (RedaplQuery, LiveServiceInstancesQuery, DebuggerHeartbeatsQuery)
# so wclip loading, login-redirect detection, and Net::HTTP setup live in one
# place.
#
# Cookies are read fresh from wclip on first use and memoized for the lifetime
# of the instance (one instance per request). They are never written to disk,
# logged, or returned.
#
# A single instance is shared across the concurrent DI Status queries, so cookie
# loading and CSRF-token retrieval are memoized under mutexes to run once even
# when several queries touch the session at the same time.
class DatadogSession
  WCLIP_HOST = 'localhost'.freeze
  WCLIP_PORT = 8093
  LOGIN_PATH = '/account/login'.freeze
  # The web-ui landing page differs per host (staging embeds the token in HTML,
  # dogfood serves a JS shell), but both expose user.csrf_token via the
  # legacy_current_user JSON endpoint, so read it from there.
  CURRENT_USER_PATH = '/api/v1/legacy_current_user'.freeze
  USER_AGENT = (
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
  ).freeze

  attr_reader :host

  def initialize(host:, cookie_label:, open_timeout: 3, read_timeout: 10)
    @host = host
    @cookie_label = cookie_label
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @cookies_mutex = Mutex.new
    @csrf_mutex = Mutex.new
  end

  def cookie_path
    "/cookies-#{@cookie_label}.json"
  end

  # GET a JSON resource on the Datadog host with the staged session cookies.
  def get_json(path)
    _, body = http_get(
      URI("https://#{@host}#{path}"),
      'cookie' => cookie_header,
      'accept' => 'application/json',
      'user-agent' => USER_AGENT
    )
    JSON.parse(body)
  end

  # POST a JSON payload to the Datadog host with the session cookies and CSRF
  # token.
  def post_json(path, payload, csrf_token:)
    uri = URI("https://#{@host}#{path}")
    request = Net::HTTP::Post.new(uri)
    request['content-type'] = 'application/json'
    request['accept'] = 'application/json'
    request['cookie'] = cookie_header
    request['x-csrf-token'] = csrf_token
    request['user-agent'] = USER_AGENT
    request.body = JSON.generate(payload)

    response = perform(request, uri)
    raise_for_response(response, path) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def csrf_token
    @csrf_mutex.synchronize { @csrf_token ||= fetch_csrf_token }
  end

  private

  def fetch_csrf_token
    token = get_json(CURRENT_USER_PATH)['csrf_token']
    raise "no csrf_token for #{@host} — session is not authenticated" if token.to_s.empty?

    token
  end

  def cookies
    @cookies_mutex.synchronize { @cookies ||= fetch_cookies }
  end

  def cookie_header
    cookies.map { |c| "#{c['name']}=#{c['value']}" }.join('; ')
  end

  def fetch_cookies
    uri = URI::HTTP.build(host: WCLIP_HOST, port: WCLIP_PORT, path: cookie_path)
    _, body = http_get(uri)
    parsed = JSON.parse(body)
    raise "expected a JSON array of cookies at #{cookie_path}" unless parsed.is_a?(Array)
    raise "no cookies staged at #{cookie_path}" if parsed.empty?

    parsed
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
