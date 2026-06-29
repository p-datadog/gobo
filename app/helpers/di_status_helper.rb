module DiStatusHelper
  # Accurate root cause for an empty DI Status page, derived from the resolved
  # DI enablement state and any probe-fetch error, instead of guessing.
  def probes_empty_state_reason(di_enabled, error = nil)
    return "Probes could not be fetched from the tracer (see the error above)." if error.present?

    case di_enabled
    when :enabled_explicitly, :enabled_implicitly
      "Dynamic instrumentation is running and ready, but no probes have been created " \
        "for this service in Datadog. Create a probe in the Datadog UI to see it here."
    when :disabled_explicitly
      "Dynamic instrumentation is explicitly disabled " \
        "(DD_DYNAMIC_INSTRUMENTATION_ENABLED=false), so the tracer receives no probes."
    when :can_enable_remotely
      "Dynamic instrumentation is not running. It can be turned on by Remote " \
        "Configuration; until it starts, the tracer receives no probes."
    else
      "Dynamic instrumentation is not available in this environment — the installed " \
        "tracer does not support it or it is unsupported here."
    end
  end
end
