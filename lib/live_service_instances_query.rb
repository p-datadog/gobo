require_relative 'datadog_session'

# Reproduces the APM-domain "live-service-instances" lookup
# (GET /api/unstable/live-service-instances?service_name=&service_env=). That
# endpoint is a Go service in the APM domain, backed by a join of
# instrumentation telemetry and REDAPL — it is NOT the source of the DI service
# page's instance-coverage panel (see DebuggerHeartbeatsQuery for that). A
# service with working DI heartbeats can still be absent here when its APM
# instrumentation telemetry is not landing in the org.
#
# The backend returns JSON:API snake_case attributes
# (active_service_instances / inactive_service_instances); the web-ui camelizes
# them on deserialize, so the raw keys read here are snake_case.
#
# Transport (wclip cookies, HTTP) is handled by DatadogSession.
class LiveServiceInstancesQuery
  ENDPOINT_PATH = '/api/unstable/live-service-instances'.freeze

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
    open_timeout: 3, read_timeout: 10, session: nil)
    @session = session || DatadogSession.new(
      host: host, cookie_label: cookie_label,
      open_timeout: open_timeout, read_timeout: read_timeout
    )
    @service = service
    @env = env
  end

  def cookie_path
    @session.cookie_path
  end

  def endpoint
    params = {service_name: @service}
    params[:service_env] = @env if @env
    "#{ENDPOINT_PATH}?#{URI.encode_www_form(params)}"
  end

  def call
    response = @session.get_json(endpoint)
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
      host: @session.host, cookie_path: cookie_path, service: @service, env: @env
    )
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
end
