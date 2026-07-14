require_relative 'datadog_session'

# Reproduces the Live Debugger instance-coverage panel the web-ui DI service
# page shows ("N instances active"). That panel is fed by the debugger
# edge-api heartbeats endpoints, NOT the APM live-service-instances service
# (see LiveServiceInstancesQuery):
#
#   GET /api/ui/debugger/services                     -> service alive (lastSeen)
#   GET /api/ui/debugger/heartbeats/details/{service} -> one row per runtime
#
# (debugger-edge-api -> debugger-api Java -> Cassandra, populated by
# debugger-heartbeat-listener from DI heartbeats.) One heartbeat row per tracer
# runtime — e.g. one per Puma cluster worker. hostname is commonly absent here,
# which surfaces as "HOSTNAME NOT DETECTED" in the UI.
#
# Transport (wclip cookies, HTTP) is handled by DatadogSession.
class DebuggerHeartbeatsQuery
  SERVICES_PATH = '/api/ui/debugger/services'.freeze
  DETAILS_PATH = '/api/ui/debugger/heartbeats/details'.freeze

  Instance = Struct.new(
    :runtime_id, :service_env, :service_version, :tracer_version,
    :language, :agent_id, :hostname, :last_seen, keyword_init: true
  )

  Result = Struct.new(
    :instances, :last_seen, :error, :host, :cookie_path, :service, :env,
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

  def services_path
    SERVICES_PATH
  end

  def details_path
    "#{DETAILS_PATH}/#{@service}"
  end

  def call
    last_seen = service_last_seen
    instances = instances_from(@session.get_json(details_path))
    result(instances: instances, last_seen: last_seen)
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(instances: [], last_seen: nil, error: nil)
    Result.new(
      instances: instances, last_seen: last_seen, error: error,
      host: @session.host, cookie_path: cookie_path, service: @service, env: @env
    )
  end

  def service_last_seen
    list = list_from(@session.get_json(services_path))
    entry = list.find { |s| s['id'] == @service }
    entry&.dig('attributes', 'lastSeen')
  end

  def instances_from(response)
    rows = list_from(response)
    rows.filter_map do |row|
      attrs = row['attributes'] || {}
      next if @env && attrs['serviceEnv'] != @env

      Instance.new(
        runtime_id: row['id'],
        service_env: attrs['serviceEnv'],
        service_version: attrs['serviceVersion'],
        tracer_version: tag_value(attrs['tags'], 'tracer_version'),
        language: attrs['tracerLanguage'],
        agent_id: attrs['datadogAgentId'],
        hostname: attrs['hostname'],
        last_seen: attrs['lastSeen']
      )
    end
  end

  # The two endpoints return either a bare JSON:API array or a { "data": [...] }
  # envelope depending on the route; accept both.
  def list_from(response)
    return response if response.is_a?(Array)

    response['data'] || []
  end

  def tag_value(tags, key)
    return nil unless tags.is_a?(Array)

    prefix = "#{key}:"
    match = tags.find { |t| t.to_s.start_with?(prefix) }
    match&.slice(prefix.length..)
  end
end
