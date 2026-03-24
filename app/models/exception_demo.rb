# Demonstrates exception scenarios for testing DI's exception_message
# C extension, which retrieves exception messages without invoking
# customer-defined message methods.
#
# Each method RAISES an exception (does not rescue internally).
# DI's method probe captures the exception in context.exception,
# which is then serialized into the snapshot's throwable field.
# The controller rescues the exception and renders it.
class ExceptionDemo
  # Standard exception with a string message.
  # exception_message returns "Record not found: id=42"
  def standard_error
    raise ActiveRecord::RecordNotFound, "Record not found: id=42"
  end

  # Custom exception class that overrides the message method.
  # exception_message returns the constructor argument ("lookup failed"),
  # NOT the overridden message ("Custom: lookup failed").
  def overridden_message
    raise InputValidationError, "lookup failed"
  end

  # Exception with a non-string constructor argument.
  # exception_message returns the Hash object; DI reports its class name
  # ("Hash") rather than calling .to_s on it.
  def non_string_message
    raise ContextError, {user: "alice", action: "delete"}
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
