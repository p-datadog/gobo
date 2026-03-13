class ProbesController < ApplicationController
  def index
    # Get active dynamic instrumentation probes from Datadog
    all_probes = fetch_all_installed_probes
    @probes = all_probes.select { |id, probe| probe.enabled? }
    @disabled_probes = all_probes.reject { |id, probe| probe.enabled? }
    @pending_probes = fetch_pending_probes
    @failed_probes = fetch_failed_probes
    @service_name = fetch_datadog_service
    @environment = fetch_datadog_env
    @di_enabled = fetch_di_enabled_status
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

    redirect_to probes_path
  end

  private

  def fetch_all_installed_probes
    @error = nil
    return {} unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return {} unless component

    probe_manager = component.probe_manager
    probe_manager.installed_probes
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

    probe_manager = component.probe_manager
    probe_manager.pending_probes
  rescue => e
    Rails.logger.error "Error fetching pending probes: #{e.class}: #{e}"
    []
  end

  def fetch_failed_probes
    return [] unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return [] unless component

    probe_manager = component.probe_manager
    probe_manager.failed_probes
  rescue => e
    Rails.logger.error "Error fetching failed probes: #{e.class}: #{e}"
    []
  end

  def fetch_datadog_service
    return nil unless defined?(Datadog)

    Datadog.configuration.service
  rescue => e
    Rails.logger.error "Error fetching Datadog service: #{e.class}: #{e}"
    nil
  end

  def fetch_datadog_env
    return nil unless defined?(Datadog)

    Datadog.configuration.env
  rescue => e
    Rails.logger.error "Error fetching Datadog environment: #{e.class}: #{e}"
    nil
  end

  def fetch_di_enabled_status
    return false unless defined?(Datadog::DI)

    component = Datadog::DI.component
    !component.nil?
  rescue => e
    Rails.logger.error "Error fetching DI enabled status: #{e.class}: #{e}"
    false
  end

  def send_probe_status(probe_id, status)
    return {success: false, error: "DI not available"} unless defined?(Datadog::DI)

    component = Datadog::DI.component
    return {success: false, error: "DI component not initialized"} unless component

    probe_manager = component.probe_manager
    all_probes = probe_manager.pending_probes.merge(probe_manager.installed_probes)
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

  def create_sample_exception
    raise RuntimeError, "Simulated probe instrumentation error: failed to capture local variable 'user' at line #{rand(100..999)}"
  rescue => e
    e
  end
end
