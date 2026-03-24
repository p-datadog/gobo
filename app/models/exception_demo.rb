# Demonstrates exception scenarios for testing DI's exception_message
# method from the libdatadog_api C extension, which retrieves exception
# messages without invoking customer-defined message methods.
#
# A single method probe on ExceptionDemo#raise_exception captures all
# three exception types. The controller calls it once per type.
class ExceptionDemo
  # Raises one of three exception types depending on the kind parameter.
  # Set a single method probe on this method to capture all cases.
  #
  # @param kind [Symbol] :standard, :overridden, or :non_string
  # @raise [ActiveRecord::RecordNotFound, InputValidationError, ContextError]
  def raise_exception(kind)
    case kind
    when :standard
      raise ActiveRecord::RecordNotFound, "Record not found: id=42"
    when :overridden
      raise InputValidationError, "lookup failed"
    when :non_string
      raise ContextError, {user: "alice", action: "delete"}
    else
      raise ArgumentError, "Unknown exception kind: #{kind}"
    end
  end

  # Custom exception with overridden message method.
  class InputValidationError < StandardError
    def message
      "Custom: #{super}"
    end
  end

  # Custom exception that accepts a non-string constructor argument.
  class ContextError < StandardError
    def message
      "ContextError(#{super.class})"
    end
  end
end
