require 'json'
require 'net/http'
require 'uri'

# Reproduces the Live Debugger "live-service-instances" lookup the web-ui uses
# to decide whether a service has any running instances. When the backend
# reports no active instances, the Dynamic Instrumentation UI shows
# "No instances found for this service".
#
# Calls GET /api/unstable/live-service-instances?service_name=&service_env= on
# the Datadog API host. The backend returns JSON:API snake_case attributes
# (active_service_instances / inactive_service_instances); the web-ui camelizes
# them on deserialize, so the raw keys read here are snake_case.
#
# The Datadog session cookies are read fresh from the local wclip web clipboard
# (/cookies-<label>.json) on every call and held only for the duration of the
# call. They are never written to disk, logged, or returned.
class LiveServiceInstancesQuery
  WCLIP_HOST = 'localhost'.freeze
  WCLIP_PORT = 8093
  ENDPOINT_PATH = '/api/unstable/live-service-instances'.freeze
  LOGIN_PATH = '/account/login'.freeze
  USER_AGENT = (
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ' \
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
  ).freeze

  Instance = Struct.new(
    :runtime_id, :hostname, :service_env, :service_version,
    :client_library_version, :agent_hostname, :agent_version,
    :di_enabled, :system_probe_enabled, :remote_config_products,
    :language_name, :last_seen, keyword_init: true
  )

  Result = Struct.new(
    :active, :inactive, :error, :endpoint, :host, :cookie_path, :service, :env,
    keyword_init: true
  ) do
    def ok?
      error.nil?
    end
  end

  def initialize(host:, cookie_label:, service:, env: nil,
    open_timeout: 3, read_timeout: 10)
    @host = host
    @cookie_label = cookie_label
    @service = service
    @env = env
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def cookie_path
    "/cookies-#{@cookie_label}.json"
  end

  def endpoint
    params = {service_name: @service}
    params[:service_env] = @env if @env
    "#{ENDPOINT_PATH}?#{URI.encode_www_form(params)}"
  end

  def call
    cookies = fetch_cookies
    response = run_query(cookies)
    result(
      active: instances_from(response, 'active_service_instances'),
      inactive: instances_from(response, 'inactive_service_instances')
    )
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(active: [], inactive: [], error: nil)
    Result.new(
      active: active, inactive: inactive, error: error, endpoint: endpoint,
      host: @host, cookie_path: cookie_path, service: @service, env: @env
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

  def run_query(cookies)
    uri = URI("https://#{@host}#{endpoint}")
    _, body = http_get(
      uri,
      'cookie' => cookie_header(cookies),
      'accept' => 'application/json',
      'user-agent' => USER_AGENT
    )
    JSON.parse(body)
  end

  def instances_from(response, key)
    list = response.dig('data', 'attributes', key) || []
    list.map { |h| instance_from(h) }
  end

  def instance_from(hash)
    Instance.new(
      runtime_id: hash['runtime_id'],
      hostname: hash['hostname'],
      service_env: hash['service_env'],
      service_version: hash['service_version'],
      client_library_version: hash['client_library_version'],
      agent_hostname: hash['agent_hostname'],
      agent_version: hash['agent_version'],
      di_enabled: hash['di_enabled'],
      system_probe_enabled: hash['system_probe_enabled'],
      remote_config_products: hash['remote_config_products'],
      language_name: hash['language_name'],
      last_seen: hash['last_seen']
    )
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
