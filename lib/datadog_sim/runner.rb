# frozen_string_literal: true

require_relative 'languages'
require_relative 'git_metadata'
require_relative 'telemetry'
require_relative 'remote_config'
require_relative 'traces'

module DatadogSim
  # Orchestrates all simulation components.
  # Each component can be independently enabled/disabled via options.
  #
  # Usage:
  #   runner = Runner.new(
  #     language: 'java',
  #     service: 'my-service',
  #     components: { telemetry: true, remote_config: true, traces: false }
  #   )
  #   runner.run  # blocks, polling RC and sending heartbeats
  class Runner
    HEARTBEAT_INTERVAL = 60   # seconds
    RC_POLL_INTERVAL   = 5    # seconds
    TRACE_INTERVAL     = 30   # seconds

    def initialize(options = {})
      lang_key = options.fetch(:language, 'java')
      lang = LANGUAGES.fetch(lang_key) { raise ArgumentError, "Unknown language: #{lang_key}. Known: #{LANGUAGES.keys.join(', ')}" }

      git = GitMetadata.resolve(
        repo_url: options[:git_repo_url],
        work_dir: options[:git_work_dir],
        branch:   options.fetch(:git_branch, 'main'),
      )

      @config = {
        language_name:      lang[:language_name],
        runtime_name:       lang[:runtime_name],
        runtime_version:    lang[:runtime_version],
        tracer_version:     lang[:tracer_version],
        rc_language:        lang[:rc_language],
        runtime_id:         options.fetch(:runtime_id, SecureRandom.uuid),
        service:            options.fetch(:service, ENV.fetch('DD_SERVICE', 'simulated-service')),
        env:                options.fetch(:env, ENV.fetch('DD_ENV', 'development')),
        version:            options.fetch(:version, ENV.fetch('DD_VERSION', '1.0')),
        agent_host:         options.fetch(:agent_host, ENV.fetch('DD_AGENT_HOST', 'localhost')),
        agent_port:         options.fetch(:agent_port, ENV.fetch('DD_TRACE_AGENT_PORT', '8126').to_i),
        git_repository_url: git[:repository_url],
        git_commit_sha:     git[:commit_sha],
        logger:             options.fetch(:logger, Logger.new($stdout)),
      }

      components = options.fetch(:components, {})
      @enable_telemetry     = components.fetch(:telemetry,     true)
      @enable_remote_config = components.fetch(:remote_config, true)
      @enable_traces        = components.fetch(:traces,        true)
      @on_symdb_config      = options[:on_symdb_config]

      build_components
    end

    # Run the simulation loop indefinitely (until interrupted).
    # Sends app-started, then polls RC at RC_POLL_INTERVAL and sends
    # heartbeats at HEARTBEAT_INTERVAL.
    def run
      log "Starting simulation (language=#{@config[:rc_language]}, service=#{@config[:service]})"
      log "Components: telemetry=#{@enable_telemetry} remote_config=#{@enable_remote_config} traces=#{@enable_traces}"

      startup
      loop { tick }
    rescue Interrupt
      log "Shutting down."
    end

    # Single iteration — useful for testing.
    def startup
      @telemetry&.send_app_started && log("Telemetry: app-started sent")
      @traces&.send_trace && log("Traces: initial trace sent")
    end

    def tick
      now = Time.now.to_f

      if @enable_remote_config && (now - @last_rc_poll) >= RC_POLL_INTERVAL
        @remote_config.poll
        @last_rc_poll = now
      end

      if @enable_telemetry && (now - @last_heartbeat) >= HEARTBEAT_INTERVAL
        @telemetry.send_heartbeat && log("Telemetry: heartbeat sent")
        @last_heartbeat = now
      end

      if @enable_traces && (now - @last_trace) >= TRACE_INTERVAL
        @traces.send_trace && log("Traces: periodic trace sent")
        @last_trace = now
      end

      sleep 1
    end

    def config
      @config.dup
    end

    private

    def build_components
      @telemetry      = @enable_telemetry     ? Telemetry.new(@config)                               : nil
      @remote_config  = @enable_remote_config ? RemoteConfig.new(@config, on_config: @on_symdb_config) : nil
      @traces         = @enable_traces        ? Traces.new(@config)                                   : nil

      @last_heartbeat = Time.now.to_f - HEARTBEAT_INTERVAL  # trigger immediately
      @last_rc_poll   = Time.now.to_f - RC_POLL_INTERVAL
      @last_trace     = Time.now.to_f - TRACE_INTERVAL
    end

    def log(message)
      @config[:logger]&.info("[DatadogSim] #{message}")
    end
  end
end
