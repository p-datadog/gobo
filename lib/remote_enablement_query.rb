require_relative 'datadog_session'

# Reads the Dynamic Instrumentation remote-enablement state the Datadog backend
# stores for a (service, env). This is the state that decides whether Remote
# Configuration turns DI on when the tracer reports
# di_enabled=can_enable_remotely.
#
# Storage: the DI enable flag lives inside the org's APM_TRACING remote-config
# config (a LibConfig field), keyed by service + env, and is served by dd-go
# rc-api as JSON:API "debugger_config" objects:
#
#   GET /api/unstable/remote_config/products/apm_tracing/debugger_configs/envs/{env}/services/{service}
#
# (dd-go: remote-config/apps/rc-api/products/apmtracing/debugger_config_routes.go)
#
# One row per client library version. dynamic_instrumentation_enabled is the
# stored toggle (nil when never set); config_exists is true once any apm_tracing
# flag has been written for the service+env; modified_time is the Unix-seconds
# last-write time of the underlying apm_tracing row (shared across all its
# flags, not DI-specific).
#
# Transport (wclip cookies, HTTP) is handled by DatadogSession.
class RemoteEnablementQuery
  PATH_TEMPLATE =
    '/api/unstable/remote_config/products/apm_tracing/debugger_configs/envs/%<env>s/services/%<service>s'.freeze

  Config = Struct.new(
    :service, :env, :config_exists, :dynamic_instrumentation_enabled,
    :language, :client_library_version, :modified_time, keyword_init: true
  )

  Result = Struct.new(
    :configs, :error, :host, :cookie_path, :service, :env, :path,
    keyword_init: true
  ) do
    def ok?
      error.nil?
    end
  end

  def initialize(host:, cookie_label:, service:, env:,
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

  def path
    format(PATH_TEMPLATE, env: @env, service: @service)
  end

  def call
    result(configs: configs_from(@session.get_json(path)))
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(configs: [], error: nil)
    Result.new(
      configs: configs, error: error, host: @session.host,
      cookie_path: cookie_path, service: @service, env: @env, path: path
    )
  end

  def configs_from(response)
    list_from(response).map do |row|
      attrs = row['attributes'] || {}
      Config.new(
        service: attrs['service'],
        env: attrs['env'],
        config_exists: attrs['config_exists'],
        dynamic_instrumentation_enabled: attrs['dynamic_instrumentation_enabled'],
        language: attrs['language'],
        client_library_version: attrs['client_library_version'],
        modified_time: attrs['modified_time']
      )
    end
  end

  # The endpoint returns either a bare JSON:API array or a { "data": [...] }
  # envelope depending on the route; accept both.
  def list_from(response)
    return response if response.is_a?(Array)

    response['data'] || []
  end
end
