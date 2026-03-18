# frozen_string_literal: true

require 'json'
require 'net/http'
require 'socket'

module DatadogSim
  # Sends Datadog telemetry events (app-started, app-heartbeat) to the agent.
  # Endpoint: POST /telemetry/proxy/api/v2/apmtelemetry
  class Telemetry
    ENDPOINT = '/telemetry/proxy/api/v2/apmtelemetry'

    def initialize(config)
      @config = config
      @seq_id = 0
    end

    def send_app_started
      payload = {
        products: {
          dynamic_instrumentation: { enabled: true },
          appsec: { enabled: false },
          profiler: { enabled: false },
        },
        configuration: git_configuration,
      }
      post('app-started', payload)
    end

    def send_heartbeat
      post('app-heartbeat', {})
    end

    private

    def post(event_type, payload)
      body = build_body(event_type, payload)
      headers = {
        'DD-Telemetry-API-Version' => 'v2',
        'DD-Telemetry-Request-Type' => event_type,
        'DD-Client-Library-Language' => @config[:language_name],
        'DD-Client-Library-Version' => @config[:tracer_version],
        'DD-Internal-Untraced-Request' => '1',
        'Content-Type' => 'application/json',
      }
      http_post(ENDPOINT, body.to_json, headers)
    end

    def build_body(event_type, payload)
      @seq_id += 1
      {
        api_version: 'v2',
        request_type: event_type,
        runtime_id: @config[:runtime_id],
        seq_id: @seq_id,
        tracer_time: Time.now.to_i,
        application: {
          service_name: @config[:service],
          env: @config[:env],
          service_version: @config[:version],
          language_name: @config[:language_name],
          language_version: @config[:runtime_version],
          runtime_name: @config[:runtime_name],
          runtime_version: @config[:runtime_version],
          tracer_version: @config[:tracer_version],
        },
        host: {
          hostname: Socket.gethostname,
          architecture: RUBY_PLATFORM,
        },
        payload: payload,
      }
    end

    def git_configuration
      items = []
      items << { name: 'DD_GIT_REPOSITORY_URL', value: @config[:git_repository_url], origin: 'env_var', seq_id: @seq_id } if @config[:git_repository_url]
      items << { name: 'DD_GIT_COMMIT_SHA', value: @config[:git_commit_sha], origin: 'env_var', seq_id: @seq_id } if @config[:git_commit_sha]
      items
    end

    def http_post(path, body, headers)
      http = Net::HTTP.new(@config[:agent_host], @config[:agent_port])
      req = Net::HTTP::Post.new(path, headers)
      req.body = body
      http.request(req)
    rescue => e
      @config[:logger]&.warn("Telemetry POST failed: #{e.class}: #{e}")
      nil
    end
  end
end
