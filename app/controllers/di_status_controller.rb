require_relative '../../lib/redapl_query'

class DiStatusController < ApplicationController
  def index
    # Get active dynamic instrumentation probes from Datadog
    all_probes = fetch_all_installed_probes
    @probes = all_probes.select { |id, probe| probe.enabled? }
    @disabled_probes = all_probes.reject { |id, probe| probe.enabled? }
    @pending_probes = fetch_pending_probes
    @failed_probes = fetch_failed_probes
    @service = fetch_service
    @env = fetch_env
    @version = fetch_version
    @git_repository_url = fetch_git_repository_url
    @git_commit_sha = fetch_git_commit_sha
    @di_enabled = fetch_di_enabled_status
    @agent_address = fetch_agent_address
    @agent_environment_label = fetch_agent_environment_label
    @agent_operational = fetch_agent_operational
    @redapl_target = fetch_agent_environment_label
    @redapl_env = redapl_env_param
    @redapl = fetch_redapl_environments(@redapl_env) if @redapl_env

    respond_to do |format|
      format.html
      format.json { render json: probes_json }
    end
  end

  def send_status
    probe_id = params[:id]
    status = params[:status]

    result = send_probe_status(probe_id, status)

    if result[:success]
      flash[:success] = "Sent #{status} status for probe #{probe_id}"
    else
      flash[:danger] = "Failed to send status: #{result[:error]}"
    end

    redirect_to di_status_path
  end

  private

  # The requested REDAPL environment. The query runs only when explicitly
  # requested, and only for a known agent environment.
  def redapl_env_param
    requested = params[:redapl].presence
    requested if requested && AgentEnvironments.all.key?(requested)
  end

  # Reads cookies fresh from wclip (/cookies-<env>.json) on every request and
  # runs the REDAPL service_config query for the current service. Cookies are
  # never stored.
  def fetch_redapl_environments(label)
    host = AgentEnvironments.fetch(label)[:host]
    result = RedaplQuery.new(host: host, cookie_label: label, service: @service).call
    {
      environment: label,
      host: result.host,
      cookie_path: result.cookie_path,
      query: result.query,
      window_minutes: result.window_minutes,
      rows: result.rows.map { |r| {service_name: r.service_name, language_name: r.language_name, env: r.env} },
      error: result.error,
    }
  end

  def fetch_all_installed_probes
    @error = nil
    return {} unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return {} unless component

    probe_manager_installed_probes(component.probe_manager)
  rescue => e
    error_message = "#{e.class}: #{e}"
    Rails.logger.error "Error fetching dynamic instrumentation probes: #{error_message}"
    @error = error_message
    {}
  end

  def fetch_pending_probes
    return [] unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return [] unless component

    probe_manager_pending_probes(component.probe_manager)
  rescue => e
    Rails.logger.error "Error fetching pending probes: #{e.class}: #{e}"
    []
  end

  def fetch_failed_probes
    return [] unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return [] unless component

    probe_manager_failed_probes(component.probe_manager)
  rescue => e
    Rails.logger.error "Error fetching failed probes: #{e.class}: #{e}"
    []
  end

  # Post-PR #5448: probe storage moved to ProbeRepository; access via probe_manager.probe_repository
  # Pre-PR #5448: methods exist directly on ProbeManager
  def probe_store(probe_manager)
    probe_manager.respond_to?(:probe_repository) ? probe_manager.probe_repository : probe_manager
  end

  def probe_manager_installed_probes(probe_manager)
    store = probe_store(probe_manager)
    store.respond_to?(:installed_probes) ? store.installed_probes : {}
  end

  def probe_manager_pending_probes(probe_manager)
    store = probe_store(probe_manager)
    store.respond_to?(:pending_probes) ? store.pending_probes : {}
  end

  def probe_manager_failed_probes(probe_manager)
    store = probe_store(probe_manager)
    store.respond_to?(:failed_probes) ? store.failed_probes : {}
  end

  # Resolves DI enablement into one of five states:
  #   :enabled_explicitly   - running because DD_DYNAMIC_INSTRUMENTATION_ENABLED=true
  #   :enabled_implicitly   - running because Remote Configuration turned it on
  #   :disabled_explicitly  - DD_DYNAMIC_INSTRUMENTATION_ENABLED=false (also blocks RC)
  #   :can_enable_remotely  - off, but Remote Configuration may turn it on
  #   :unavailable          - DI absent or unsupported in this environment
  def fetch_di_enabled_status
    return :unavailable unless defined?(Datadog::DI) && Datadog::DI.respond_to?(:component)
    return :disabled_explicitly if di_explicitly_disabled?

    if di_component_running?(Datadog::DI.component)
      return di_explicitly_enabled? ? :enabled_explicitly : :enabled_implicitly
    end

    di_supports_remote_enablement? && !di_unsupported? ? :can_enable_remotely : :unavailable
  rescue => e
    Rails.logger.error "Error fetching DI enabled status: #{e.class}: #{e}"
    :unavailable
  end

  def di_component_running?(component)
    return false unless component
    return component.started? if component.respond_to?(:started?)

    # Tracers without implicit enablement only build the component when DI is
    # actually on, so a present component means DI is running.
    true
  end

  def di_explicitly_enabled?
    if defined?(Datadog::DI::Component) && Datadog::DI::Component.respond_to?(:explicitly_enabled?)
      return Datadog::DI::Component.explicitly_enabled?(Datadog.configuration)
    end

    di_setting_explicitly?(true)
  end

  def di_explicitly_disabled?
    if defined?(Datadog::DI::Remote) && Datadog::DI::Remote.respond_to?(:explicitly_disabled?)
      return Datadog::DI::Remote.explicitly_disabled?(Datadog.configuration)
    end

    di_setting_explicitly?(false)
  end

  # Fallback for tracers that lack DI::Component.explicitly_enabled? /
  # DI::Remote.explicitly_disabled?: read the setting directly and confirm it
  # was set by the customer rather than left at its default.
  def di_setting_explicitly?(value)
    config = Datadog.configuration
    return false unless config.respond_to?(:dynamic_instrumentation)

    settings = config.dynamic_instrumentation
    return false unless settings.respond_to?(:using_default?)

    !settings.using_default?(:enabled) && settings.enabled == value
  rescue => e
    Rails.logger.error "Error reading DI setting: #{e.class}: #{e}"
    false
  end

  # Remote enablement requires a tracer that can start DI at runtime, which is
  # the same tracer that exposes Component#started?.
  def di_supports_remote_enablement?
    defined?(Datadog::DI::Component) && Datadog::DI::Component.method_defined?(:started?)
  end

  def di_unsupported?
    return false unless Datadog::DI.respond_to?(:unsupported_reason)

    !Datadog::DI.unsupported_reason(Datadog.configuration).nil?
  rescue => e
    Rails.logger.error "Error reading DI support status: #{e.class}: #{e}"
    false
  end

  def send_probe_status(probe_id, status)
    return {success: false, error: "DI not available"} unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return {success: false, error: "DI component not initialized"} unless component

    probe_manager = component.probe_manager
    all_probes = probe_manager_pending_probes(probe_manager).merge(probe_manager_installed_probes(probe_manager))
    probe = all_probes[probe_id]

    return {success: false, error: "Probe not found"} unless probe

    builder = probe_manager.probe_notification_builder
    notifier = probe_manager.probe_notifier_worker

    payload = case status
    when 'installed'
      builder.build_installed(probe)
    when 'emitting'
      builder.build_emitting(probe)
    when 'disabled'
      builder.build_disabled(probe, 1.5)
    when 'error'
      builder.build_errored(probe, nil)
    when 'error_with_exception'
      exception = create_sample_exception
      builder.build_errored(probe, exception)
    else
      return {success: false, error: "Unknown status: #{status}"}
    end

    notifier.add_status(payload, probe: probe)

    {success: true}
  rescue => e
    Rails.logger.error "Error sending probe status: #{e.class}: #{e}"
    {success: false, error: "#{e.class}: #{e}"}
  end

  def probes_json
    {
      service: @service,
      env: @env,
      version: @version,
      git_repository_url: @git_repository_url,
      git_commit_sha: @git_commit_sha,
      agent_address: @agent_address,
      di_enabled: @di_enabled.to_s,
      active: serialize_probes(@probes),
      disabled: serialize_probes(@disabled_probes),
      pending: serialize_probes(@pending_probes),
      failed: serialize_probes(@failed_probes),
      error: @error,
      redapl: @redapl,
      agent_operational: @agent_operational&.operational?,
    }
  end

  def serialize_probes(probes)
    return [] unless probes
    collection = probes.is_a?(Hash) ? probes.values : probes
    collection.map { |p| serialize_probe(p) }
  end

  def serialize_probe(probe)
    {
      id: probe.id,
      type: probe.type,
      file: probe.file,
      line_no: probe.line_no,
      type_name: probe.type_name,
      method_name: probe.method_name,
      rate_limit: probe.rate_limit,
    }.compact
  end

  def create_sample_exception
    raise RuntimeError, "Simulated probe instrumentation error: failed to capture local variable 'user' at line #{rand(100..999)}"
  rescue => e
    e
  end
end
