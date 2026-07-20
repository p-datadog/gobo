module DiStatusHelper
  # True when runtime_id belongs to one of this server's live worker
  # processes, i.e. the backend row describes the currently running process.
  def di_local_runtime?(local_runtime_ids, runtime_id)
    return false if runtime_id.blank?

    Array(local_runtime_ids).include?(runtime_id)
  end

  # Accurate root cause for an empty DI Status page, derived from the resolved
  # DI enablement state and any probe-fetch error, instead of guessing.
  def probes_empty_state_reason(di_enabled, error = nil, unavailable_reason = nil)
    return "Probes could not be fetched from the tracer (see the error above)." if error.present?

    case di_enabled
    when :enabled_explicitly, :enabled_implicitly
      "Dynamic instrumentation is running and ready, but no probes have been created " \
        "for this service in Datadog. Create a probe in the Datadog UI to see it here."
    when :disabled_explicitly
      "Dynamic instrumentation is explicitly disabled " \
        "(DD_DYNAMIC_INSTRUMENTATION_ENABLED=false), so the tracer receives no probes."
    when :explicitly_enabled_rc_disabled
      "Dynamic instrumentation was explicitly enabled " \
        "(DD_DYNAMIC_INSTRUMENTATION_ENABLED=true) but Remote Configuration has turned " \
        "it off, so the tracer currently receives no probes."
    when :can_enable_remotely
      "Dynamic instrumentation is not running. It can be turned on by Remote " \
        "Configuration; until it starts, the tracer receives no probes."
    when :error
      "Dynamic instrumentation status could not be determined — an error occurred " \
        "while checking it (see the error above)."
    else
      if unavailable_reason.present?
        "Dynamic instrumentation is not available in this environment: #{unavailable_reason}."
      else
        "Dynamic instrumentation is not available in this environment — the installed " \
          "tracer does not support it or it is unsupported here."
      end
    end
  end

  # Human "N ago" for an ISO8601 timestamp string, or nil when blank/unparseable.
  def time_ago_since(timestamp)
    return nil if timestamp.blank?

    parsed = Time.zone.parse(timestamp.to_s)
    parsed && "#{time_ago_in_words(parsed)} ago"
  rescue ArgumentError
    nil
  end

  # The original DI expression-language DSL for a capture expression, rendered
  # as pretty JSON. nil when the tracer does not retain the source DSL.
  def capture_expression_dsl_json(expression)
    return nil unless expression.respond_to?(:expr)

    expr = expression.expr
    return nil unless expr.respond_to?(:dsl_expr)

    JSON.pretty_generate(expr.dsl_expr)
  end

  # Per-expression capture-limit overrides as "key=value" text, or "none" when
  # the expression sets no overrides (limits fall back to the probe/settings).
  def capture_expression_limits_text(expression)
    limits = expression.limits if expression.respond_to?(:limits)
    return "none" unless limits

    parts = {
      "maxReferenceDepth" => limits.max_reference_depth,
      "maxCollectionSize" => limits.max_collection_size,
      "maxLength" => limits.max_length,
      "maxFieldCount" => limits.max_field_count,
    }.reject { |_, value| value.nil? }.map { |key, value| "#{key}=#{value}" }

    parts.empty? ? "none" : parts.join(", ")
  end
end
