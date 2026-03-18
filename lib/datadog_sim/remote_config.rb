# frozen_string_literal: true

# Polls the Datadog agent Remote Configuration endpoint (/v0.7/config).
#
# == Backend Requirements (debugger-backend/Heartbeat.kt, TracerVersionChecker.kt)
#
# For the backend to recognise this client as an alive DI-enabled tracer and
# begin delivering configs, ALL of the following must hold:
#
# 1. CAPABILITIES (REQUIRED — non-obvious)
#    The `client.capabilities` field must be a non-empty Base64 bitmask.
#    An empty string or Base64("\x00") causes the backend to return
#    `"targets": {}` on every poll — no configs are ever delivered.
#    Must include APM_TRACING bits (12, 13, 14, 29). See CAPABILITIES constant.
#
# 2. TRACER VERSION (REQUIRED — must be valid semver above minimum)
#    `client_tracer.tracer_version` is parsed by TracerVersionChecker.
#    An invalid version like "1.x.x" is rejected and the heartbeat is discarded.
#    Minimums by language for DI:
#      java>=1.5.0, dotnet>=2.23.0, python>=1.8.0, go>=1.64.0,
#      ruby>=2.9.0, node>=5.39.0, php>=1.5.0
#    Minimums for SymDB:
#      java>=1.34.0, dotnet>=2.57.0, python>=2.9.0, ruby>=2.11.0
#    See lib/datadog_sim/languages.rb for the values used per language.
#
# 3. PRODUCTS (REQUIRED)
#    Must declare LIVE_DEBUGGING and/or LIVE_DEBUGGING_SYMBOL_DB.
#    APM_TRACING is also included to match a real tracer.
#
# 4. TUF BOOTSTRAP (REQUIRED — must complete before configs arrive)
#    The agent uses TUF (The Update Framework). On first connect the agent
#    returns a `roots` array. The client must ACCUMULATE root_version
#    (root_version += roots.size) across polls until roots stop arriving.
#    Using assignment (root_version = roots.size) resets it on each poll
#    and loops forever in the bootstrap phase.
#
# 5. STATE ADVANCEMENT (REQUIRED — backend won't send new configs without it)
#    targets_version and backend_client_state (opaque_backend_state) must be
#    extracted from the decoded `targets` field and sent back on the next
#    request. Without this the backend resends the same targets repeatedly.
#
# 6. STABLE client_id AND runtime_id (REQUIRED)
#    The backend tracks instances by these values. They must remain constant
#    across all polls for the session, otherwise each poll looks like a new
#    unknown instance.

require 'base64'
require 'json'
require 'net/http'
require 'securerandom'

module DatadogSim
  class RemoteConfig
    ENDPOINT = '/v0.7/config'

    # REQUIRED: non-empty APM_TRACING capability bitmask.
    # See requirement #1 in the file header above.
    # bits 12,13,14,29 = APM_TRACING_SAMPLE_RATE, LOGS_INJECTION, HTTP_HEADER_TAGS, SAMPLE_RULES
    # (1<<12)|(1<<13)|(1<<14)|(1<<29) = 0x20007000 = bytes [32, 0, 112, 0] = "IABwAA=="
    CAPABILITIES = Base64.strict_encode64([32, 0, 112, 0].pack('C*'))

    def initialize(config, on_config: nil)
      @config = config
      @on_config = on_config
      # Requirement #6: stable IDs across all polls in this session.
      @client_id = SecureRandom.uuid
      @root_version = 1
      @targets_version = 0
      @config_states = []
      @backend_client_state = ''
    end

    def poll
      body = build_payload
      headers = { 'Content-Type' => 'application/json' }
      response = http_post(ENDPOINT, body.to_json, headers)
      if response.nil?
        @config[:logger]&.debug("RC: no response from agent")
        return
      end
      @config[:logger]&.debug("RC: response #{response.code} body=#{response.body.to_s[0, 200].inspect}")
      handle_response(response) if response.code == '200'
    rescue => e
      @config[:logger]&.warn("RC poll failed: #{e.class}: #{e}\n#{e.backtrace.first(3).join("\n")}")
    end

    private

    def build_payload
      {
        client: {
          id: @client_id,
          # Requirement #3: must declare LIVE_DEBUGGING / LIVE_DEBUGGING_SYMBOL_DB.
          products: ['APM_TRACING', 'LIVE_DEBUGGING', 'LIVE_DEBUGGING_SYMBOL_DB'],
          is_tracer: true,
          is_agent: false,
          capabilities: CAPABILITIES,  # Requirement #1
          state: {
            # Requirements #4 and #5: must advance these across polls.
            root_version: @root_version,
            targets_version: @targets_version,
            config_states: @config_states,
            has_error: false,
            error: '',
            backend_client_state: @backend_client_state,
          },
          client_tracer: {
            runtime_id: @config[:runtime_id],  # Requirement #6
            # Requirement #2: language + tracer_version validated by TracerVersionChecker.
            language: @config[:rc_language],
            tracer_version: @config[:tracer_version],
            service: @config[:service],
            env: @config[:env],
            app_version: @config[:version],
            tags: build_tags,
          },
        },
        cached_target_files: [],
      }
    end

    def build_tags
      tags = []
      tags << "git.repository_url:#{@config[:git_repository_url]}" if @config[:git_repository_url]
      tags << "git.commit.sha:#{@config[:git_commit_sha]}" if @config[:git_commit_sha]
      tags
    end

    def handle_response(response)
      raw = response.body
      body = JSON.parse(raw) rescue nil
      unless body.is_a?(Hash)
        @config[:logger]&.debug("RC: unexpected response type #{body.class} (body: #{raw.to_s[0, 200].inspect})")
        return
      end
      return if body.empty?

      # Requirement #4: TUF bootstrap — accumulate root_version.
      # Agent returns 'roots' array while our root_version is behind.
      # IMPORTANT: use += not = (assignment would reset to 1 on the next batch,
      # causing an infinite bootstrap loop: 1 batch of 15 roots → version=15,
      # then 1 more root → version=1 again instead of 16).
      roots = body['roots']
      if roots.is_a?(Array) && roots.size > 0
        @root_version += roots.size
        @config[:logger]&.debug("RC: processed #{roots.size} roots, root_version now #{@root_version}")
      end

      # Requirement #5: advance targets_version and backend_client_state.
      # 'targets' is a base64-encoded TUF JSON string (not a nested hash).
      # Must decode and extract these values to send back on the next request.
      # Without this the backend resends the same targets on every poll.
      targets_raw = body['targets']
      if targets_raw.is_a?(String)
        targets = JSON.parse(Base64.decode64(targets_raw)) rescue nil
        if targets.is_a?(Hash)
          signed = targets['signed']
          if signed.is_a?(Hash)
            @targets_version = signed['version'] || @targets_version
            @backend_client_state = signed.dig('custom', 'opaque_backend_state') || @backend_client_state
            target_keys = signed['targets']&.keys || []
            if target_keys.empty?
              @config[:logger]&.debug("RC: targets_version=#{@targets_version}, no configs (service not yet known to backend)")
            else
              @config[:logger]&.debug("RC: targets_version=#{@targets_version}, configs=#{target_keys.inspect}")
            end
          end
        end
      end

      client_configs = body['client_configs']
      return unless client_configs.is_a?(Array) && !client_configs.empty?

      @config[:logger]&.info("RC: client_configs received: #{client_configs.inspect}")

      client_configs.each do |path|
        next unless path.is_a?(String)
        if path.include?('LIVE_DEBUGGING_SYMBOL_DB')
          config_content = extract_config_content(body, path)
          if config_content.is_a?(Hash) && config_content['upload_symbols']
            @config[:logger]&.info("RC: received upload_symbols=true, triggering upload")
            @on_config&.call({ upload_symbols: true })
          else
            @config[:logger]&.debug("RC: LIVE_DEBUGGING_SYMBOL_DB config content: #{config_content.inspect}")
          end
        else
          @config[:logger]&.debug("RC: ignoring config for other product: #{path}")
        end
      end
    end

    def extract_config_content(body, path)
      encoded = body.dig('target_files')&.find { |f| f['path'] == path }&.dig('raw')
      return nil unless encoded
      JSON.parse(Base64.decode64(encoded)) rescue nil
    end

    def http_post(path, body, headers)
      http = Net::HTTP.new(@config[:agent_host], @config[:agent_port])
      req = Net::HTTP::Post.new(path, headers)
      req.body = body
      http.request(req)
    rescue => e
      @config[:logger]&.warn("RC POST failed: #{e.class}: #{e}")
      nil
    end
  end
end
