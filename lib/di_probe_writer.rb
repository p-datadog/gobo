require 'json'
require 'securerandom'
require_relative 'datadog_session'

# Creates and deletes Dynamic Instrumentation log probes through the rc-api
# livedebugging product, the same API the DI UI uses. This drives the probe
# side of the multi-config / implicit-enablement end-to-end demo from the CLI
# (see claude-projects/projects/multi-config/testing/test-strategy.md Tier 3)
# without clicking through the UI.
#
# Routes (dd-go remote-config/apps/rc-api/products/livedebugging/router.go):
#   POST   /api/ui/remote_config/products/live_debugging/probes/log/        create
#   DELETE /api/ui/remote_config/products/live_debugging/probes/log/{id}    delete
#   GET    /api/ui/remote_config/products/live_debugging/probes/             list
#
# The create body is google/jsonapi format (github.com/google/jsonapi), matching
# the LogProbeAndMetadata struct in
# remote-config/apps/rc-api/products/livedebugging/jsonapiconf/domain.go:
#   { "data": { "type": "di_log_probe", "attributes": {
#       "version": 0, "disabled": false,
#       "metadata": { "service_name": ..., "type": "LOG_PROBE",
#         "enablement": { "queries": [{ "text": "env:<env>",
#           "tags": [{ "key": "env", "values": [{ "value": "<env>" }] }] }] } },
#       "probe": { "where": { "type_name": ..., "method_name": ... },
#         "language": ..., "tags": [], "template": "", "capture_snapshot": bool } } }
#
# Transport (wclip cookies, CSRF on writes) is handled by DatadogSession.
class DIProbeWriter
  BASE_PATH = '/api/ui/remote_config/products/live_debugging'.freeze
  LOG_PROBES_PATH = "#{BASE_PATH}/probes/log/".freeze
  ALL_PROBES_PATH = "#{BASE_PATH}/probes/".freeze
  PROBE_TYPE = 'di_log_probe'.freeze
  LOG_PROBE_CONFIG_TYPE = 'LOG_PROBE'.freeze

  Result = Struct.new(:id, :error, :host, :cookie_path, :service, :env,
    keyword_init: true) do
    def ok?
      error.nil?
    end
  end

  ListResult = Struct.new(:probes, :error, :host, :cookie_path, :service,
    keyword_init: true) do
    def ok?
      error.nil?
    end
  end

  Probe = Struct.new(:id, :service, :env, :where, :language, :capture_snapshot,
    keyword_init: true)

  attr_reader :service, :env

  def initialize(host:, cookie_label:, service:, env:, language: 'ruby',
    open_timeout: 3, read_timeout: 10, session: nil)
    @session = session || DatadogSession.new(
      host: host, cookie_label: cookie_label,
      open_timeout: open_timeout, read_timeout: read_timeout
    )
    @service = service
    @env = env
    @language = language
  end

  def cookie_path
    @session.cookie_path
  end

  # Create a method log probe on +type_name#method_name+. Returns a Result
  # with the new probe id. The probe id is server-assigned (uuid) when omitted;
  # we send a client-generated uuid so create + later delete are idempotent
  # against the same id.
  def create(type_name:, method_name:, capture_snapshot: true, template: '')
    id = SecureRandom.uuid
    body = build_body(id: id, type_name: type_name, method_name: method_name,
      capture_snapshot: capture_snapshot, template: template)
    response = @session.post_json(LOG_PROBES_PATH, body, csrf_token: @session.csrf_token)
    returned_id = probe_id_from(response) || id
    Result.new(id: returned_id, host: @session.host, cookie_path: cookie_path,
      service: @service, env: @env)
  rescue => e
    Result.new(error: "#{e.class}: #{e}", host: @session.host,
      cookie_path: cookie_path, service: @service, env: @env)
  end

  # Delete a probe by id. Returns a Result (id set on success).
  def delete(probe_id)
    @session.delete_json("#{LOG_PROBES_PATH}#{probe_id}", csrf_token: @session.csrf_token)
    Result.new(id: probe_id, host: @session.host, cookie_path: cookie_path,
      service: @service, env: @env)
  rescue => e
    Result.new(error: "#{e.class}: #{e}", id: probe_id, host: @session.host,
      cookie_path: cookie_path, service: @service, env: @env)
  end

  # List probes the backend holds for the running service. The /probes/
  # endpoint returns every probe in the org; the running service is selected
  # client-side via the per-entry service field.
  def list
    response = @session.get_json(ALL_PROBES_PATH)
    ListResult.new(probes: probes_for_service(response), host: @session.host,
      cookie_path: cookie_path, service: @service)
  rescue => e
    ListResult.new(error: "#{e.class}: #{e}", host: @session.host,
      cookie_path: cookie_path, service: @service)
  end

  private

  def build_body(id:, type_name:, method_name:, capture_snapshot:, template:)
    {
      'data' => {
        'type' => PROBE_TYPE,
        'id' => id,
        'attributes' => {
          'version' => 0,
          'disabled' => false,
          'metadata' => {
            'service_name' => @service,
            'type' => LOG_PROBE_CONFIG_TYPE,
            'enablement' => {
              'queries' => [
                {
                  'text' => "env:#{@env}",
                  'tags' => [
                    { 'key' => 'env',
                      'values' => [{ 'value' => @env, 'is_excluded' => false }] },
                  ],
                },
              ],
            },
          },
          'probe' => {
            'version' => 0,
            'where' => { 'type_name' => type_name, 'method_name' => method_name },
            'language' => @language,
            'tags' => [],
            'template' => template,
            'segments' => [],
            'capture_snapshot' => capture_snapshot,
          },
        },
      },
    }
  end

  def probe_id_from(response)
    data = response.is_a?(Hash) ? response['data'] : response
    data = data.first if data.is_a?(Array)
    data.is_a?(Hash) ? data['id'] : nil
  end

  def probes_for_service(response)
    list_from(response).filter_map do |row|
      attrs = row.is_a?(Hash) ? (row['attributes'] || row) : {}
      meta = attrs['metadata'] || {}
      next unless meta['service_name'] == @service

      probe = attrs['probe'] || {}
      where = probe['where'] || {}
      Probe.new(
        id: row['id'],
        service: meta['service_name'],
        env: env_from(meta),
        where: where['type_name'].to_s + (where['method_name'] ? "##{where['method_name']}" : ''),
        language: probe['language'],
        capture_snapshot: probe['capture_snapshot']
      )
    end
  end

  def env_from(metadata)
    enablement = metadata['enablement'] || {}
    queries = enablement['queries'] || []
    queries.flat_map { |q| (q['tags'] || []).select { |t| t['key'] == 'env' }
                                   .flat_map { |t| (t['values'] || []).map { |v| v['value'] } } }
          .first
  end

  def list_from(response)
    return response if response.is_a?(Array)

    response && response['data'] ? response['data'] : []
  end
end
