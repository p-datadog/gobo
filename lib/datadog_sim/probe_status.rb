# frozen_string_literal: true

require 'json'
require 'net/http'
require 'securerandom'

module DatadogSim
  # Sends probe status events to the Datadog agent so the DI UI shows
  # probes as INSTALLED rather than stuck in RECEIVED.
  #
  # Endpoint: POST /debugger/v1/diagnostics
  # Payload: JSON array of probe status events
  class ProbeStatus
    ENDPOINT = '/debugger/v1/diagnostics'

    def initialize(config)
      @config = config
    end

    # Send INSTALLED status for a probe.
    # @param probe_id [String] the probe ID from the RC config
    def send_installed(probe_id)
      send_status(probe_id, 'INSTALLED', "Probe #{probe_id} has been instrumented correctly")
    end

    # Send RECEIVED status for a probe.
    def send_received(probe_id)
      send_status(probe_id, 'RECEIVED', "Probe #{probe_id} has been received correctly")
    end

    private

    def send_status(probe_id, status, message)
      event = {
        service:   @config[:service],
        timestamp: (Time.now.to_f * 1000).to_i,
        message:   message,
        ddsource:  'dd_debugger',
        debugger: {
          diagnostics: {
            probeId:      probe_id,
            probeVersion: 0,
            runtimeId:    @config[:runtime_id],
            parentId:     nil,
            status:       status,
          },
        },
      }

      body = [event].to_json
      headers = { 'Content-Type' => 'application/json' }
      response = http_post(ENDPOINT, body, headers)
      @config[:logger]&.info("ProbeStatus: sent #{status} for probe #{probe_id} → #{response&.code}")
    rescue => e
      @config[:logger]&.warn("ProbeStatus: failed to send #{status}: #{e.class}: #{e}")
    end

    def http_post(path, body, headers)
      http = Net::HTTP.new(@config[:agent_host], @config[:agent_port])
      req = Net::HTTP::Post.new(path, headers)
      req.body = body
      http.request(req)
    end
  end
end
