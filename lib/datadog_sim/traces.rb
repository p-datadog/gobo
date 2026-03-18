# frozen_string_literal: true

require 'json'
require 'net/http'
require 'securerandom'

module DatadogSim
  # Sends minimal traces to the Datadog agent.
  # Endpoint: POST /v0.4/traces (JSON-encoded)
  #
  # v0.4 accepts both msgpack and JSON. We use JSON to avoid the msgpack
  # dependency so this script runs with stdlib only.
  #
  # Sends a single synthetic span to register the service as active and
  # carry git metadata tags on the first span.
  class Traces
    ENDPOINT = '/v0.4/traces'

    def initialize(config)
      @config = config
    end

    def send_trace
      span = build_span
      body = [[span]].to_json
      headers = {
        'Content-Type' => 'application/json',
        'X-Datadog-Trace-Count' => '1',
      }
      http_post(ENDPOINT, body, headers)
    rescue => e
      @config[:logger]&.warn("Trace POST failed: #{e.class}: #{e}")
      nil
    end

    private

    def build_span
      now_ns = (Time.now.to_f * 1_000_000_000).to_i
      meta = {
        'env' => @config[:env],
        'version' => @config[:version],
        'language' => @config[:language_name],
        'runtime-id' => @config[:runtime_id],
      }
      meta['_dd.git.repository_url'] = @config[:git_repository_url] if @config[:git_repository_url]
      meta['_dd.git.commit.sha'] = @config[:git_commit_sha] if @config[:git_commit_sha]

      {
        'trace_id' => rand(2**64),
        'span_id' => rand(2**64),
        'parent_id' => 0,
        'name' => 'datadog.simulated.request',
        'service' => @config[:service],
        'resource' => 'simulated',
        'type' => 'web',
        'start' => now_ns,
        'duration' => 1_000_000,
        'error' => 0,
        'meta' => meta,
        'metrics' => { '_dd.top_level' => 1.0, '_sampling_priority_v1' => 1.0 },
      }
    end

    def http_post(path, body, headers)
      http = Net::HTTP.new(@config[:agent_host], @config[:agent_port])
      req = Net::HTTP::Post.new(path, headers)
      req.body = body
      http.request(req)
    end
  end
end
