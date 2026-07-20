require_relative 'datadog_session'

# Lists Live Debugger sessions and narrows them to the running service.
#
#   GET /api/ui/debugger/live-debugger/sessions
#
# The endpoint returns every session in the org (JSON:API "session" objects);
# each carries the services it targets in service_names, so the running service
# is selected client-side. Note the wire attributes are snake_case here, unlike
# the camelCase debugger heartbeats/probe-statuses endpoints. A session groups probes under a name with an
# optional expiry (expires is Unix ms; 0 = never).
#
# Transport (wclip cookies, HTTP) is handled by DatadogSession.
class DebuggerSessionsQuery
  SESSIONS_PATH = '/api/ui/debugger/live-debugger/sessions'.freeze

  Session = Struct.new(
    :id, :name, :num_probes, :disabled, :expires, :created_by, :created_at,
    :service_names, :git_repositories, keyword_init: true
  )

  Result = Struct.new(
    :sessions, :error, :host, :cookie_path, :service, keyword_init: true
  ) do
    def ok?
      error.nil?
    end
  end

  def initialize(host:, cookie_label:, service:,
    open_timeout: 3, read_timeout: 10, session: nil)
    @session = session || DatadogSession.new(
      host: host, cookie_label: cookie_label,
      open_timeout: open_timeout, read_timeout: read_timeout
    )
    @service = service
  end

  def cookie_path
    @session.cookie_path
  end

  def sessions_path
    SESSIONS_PATH
  end

  def call
    result(sessions: sessions_for_service(@session.get_json(sessions_path)))
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(sessions: [], error: nil)
    Result.new(
      sessions: sessions, error: error, host: @session.host,
      cookie_path: cookie_path, service: @service
    )
  end

  def sessions_for_service(response)
    list_from(response).filter_map do |row|
      attrs = row['attributes'] || {}
      service_names = Array(attrs['service_names'])
      next unless service_names.include?(@service)

      Session.new(
        id: row['id'],
        name: attrs['name'],
        num_probes: attrs['num_probes'],
        disabled: attrs['disabled'],
        expires: attrs['expires'],
        created_by: attrs['created_by'],
        created_at: attrs['created_at'],
        service_names: service_names,
        git_repositories: Array(attrs['git_repositories'])
      )
    end
  end

  def list_from(response)
    return response if response.is_a?(Array)

    response['data'] || []
  end
end
