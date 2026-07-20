require_relative 'datadog_session'

# Lists the probes the Datadog backend holds and their aggregate status,
# narrowed to the running service.
#
#   GET /api/ui/debugger/probe-statuses
#
# This is the backend's per-probe view (one entry per probe id, aggregated
# across all reporting runtimes), distinct from the in-process probe list at
# the top of the DI Status page (what this tracer received). status is one of
# WAITING, ACTIVE, ERROR, DISABLED, NO_AGENTS, EXPIRED, OVER_LIMIT. The
# endpoint returns every probe in the org; the running service is selected
# client-side via the per-entry service field.
#
# Transport (wclip cookies, HTTP) is handled by DatadogSession.
class ProbeStatusesQuery
  STATUSES_PATH = '/api/ui/debugger/probe-statuses'.freeze

  Diagnostic = Struct.new(:runtime_id, :status, :exception, :timestamp, keyword_init: true)

  ProbeStatus = Struct.new(
    :id, :service, :status, :summary, :last_captured, :probe_updated_at,
    :diagnostics, :stale, keyword_init: true
  )

  Result = Struct.new(
    :probes, :error, :host, :cookie_path, :service, keyword_init: true
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

  def statuses_path
    STATUSES_PATH
  end

  def call
    result(probes: probes_for_service(@session.get_json(statuses_path)))
  rescue => e
    result(error: "#{e.class}: #{e}")
  end

  private

  def result(probes: [], error: nil)
    Result.new(
      probes: probes, error: error, host: @session.host,
      cookie_path: cookie_path, service: @service
    )
  end

  def probes_for_service(response)
    list_from(response).filter_map do |row|
      attrs = row['attributes'] || {}
      next unless attrs['service'] == @service

      ProbeStatus.new(
        id: row['id'],
        service: attrs['service'],
        status: attrs['status'],
        summary: Array(attrs['summary']),
        last_captured: attrs['lastCaptured'],
        probe_updated_at: attrs['probeUpdatedAt'],
        diagnostics: diagnostics_from(attrs['diagnostics']),
        stale: attrs['stale']
      )
    end
  end

  def diagnostics_from(list)
    Array(list).map do |d|
      exception = d['exception']
      Diagnostic.new(
        runtime_id: d['runtimeId'],
        status: d['status'],
        exception: exception && {type: exception['type'], message: exception['message']},
        timestamp: d['timestamp']
      )
    end
  end

  def list_from(response)
    return response if response.is_a?(Array)

    response['data'] || []
  end
end
