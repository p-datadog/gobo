class DebuggerTestController < ApplicationController
  # No CSRF token verification needed - these are GET endpoints which are
  # exempt from CSRF protection by Rails convention (GET requests should be idempotent)

  def calculate
    # Get fibonacci_n from params, default to ExpensiveModel::DEFAULT_FIBONACCI_N
    fibonacci_n = params[:fibonacci_n]&.to_i || ExpensiveModel::DEFAULT_FIBONACCI_N

    # Cap at 40 to prevent extremely long computations
    fibonacci_n = [fibonacci_n, 40].min

    result = nil
    execution_time = Benchmark.realtime do
      result = ExpensiveModel.fibonacci(fibonacci_n)
    end

    # Build response string separately to avoid static analysis false positives
    response_text = "fibonacci(#{fibonacci_n}) = #{result}. Execution time: #{(execution_time * 1000).round(2)}ms"
    render plain: response_text
  end

  def circuit_breaker
    # Get fibonacci_n from params, default to ExpensiveModel::DEFAULT_FIBONACCI_N
    fibonacci_n = params[:fibonacci_n]&.to_i || ExpensiveModel::DEFAULT_FIBONACCI_N

    # Cap at 40 to prevent extremely long computations
    fibonacci_n = [fibonacci_n, 40].min

    # Circuit breaker test: Create ExpensiveModel which triggers custom serializer when captured by DI
    execution_time = Benchmark.realtime do
      model = ExpensiveModel.new(n: fibonacci_n)
      model.process
    end

    # Build response string separately to avoid static analysis false positives
    response_text = "ExpensiveModel processed with n=#{fibonacci_n}. Execution time: #{(execution_time * 1000).round(2)}ms"
    render plain: response_text
  end

  def exception_message
    # Render the exception_message demo page
  end

  # Each action calls ExceptionDemo#raise_exception with a different kind.
  # A single method probe on raise_exception captures all three cases.
  # Exceptions are always rescued so the UI works with or without DI.

  def exception_standard
    demo = ExceptionDemo.new
    demo.raise_exception(:standard)
  rescue => exc
    render plain: "#{exc.class}: #{exc.message}"
  end

  def exception_overridden
    demo = ExceptionDemo.new
    demo.raise_exception(:overridden)
  rescue => exc
    render plain: "#{exc.class}: #{exc.message}"
  end

  def exception_non_string
    demo = ExceptionDemo.new
    demo.raise_exception(:non_string)
  rescue => exc
    render plain: "#{exc.class}: #{exc.message}"
  end

  def stdlib_probe
    # Render the stdlib line probe demo page
  end

  def stdlib_probe_run
    kind = params[:kind]
    result = case kind
    when "uri_parse"
      url = "https://example.com/users/42?lang=en&debug=true"
      parsed = URI.parse(url)
      "URI.parse(#{url.inspect}) => host=#{parsed.host}, path=#{parsed.path}, query=#{parsed.query}"
    when "pathname_join"
      base = Pathname.new("/var/log")
      joined = base.join("app", "production.log")
      "Pathname#join(/var/log, app, production.log) => #{joined}"
    when "digest_sha256"
      input = "hello world #{Time.now.to_i}"
      hash = Digest::SHA256.hexdigest(input)
      "Digest::SHA256.hexdigest(#{input.inspect}) => #{hash}"
    else
      "Unknown kind: #{kind}"
    end
    render plain: result
  rescue => e
    render plain: "#{e.class}: #{e}"
  end

  def json_error
    # Render the JSON encoding error demo page
  end

  def binary_data_param
    # Pass a real binary string (all 256 byte values) as a method argument.
    # The custom serializer condition checks value.metadata[:trigger_json_error]
    # on the BinaryDataModel instance, not on the data argument — so DI
    # serializes the binary string argument natively without error.
    binary = (0..255).map { |b| b.chr(Encoding::ASCII_8BIT) }.join

    model = BinaryDataModel.new
    result = model.process(binary)

    render plain: "BinaryDataModel#process called with binary data argument. Size: #{binary.length} bytes, encoding: #{binary.encoding}"
  end

  def binary_data
    # Get trigger_error from params, default to false
    trigger_error = params[:trigger_error] == 'true'

    execution_time = Benchmark.realtime do
      # Create BinaryDataModel with metadata flag controlling serializer behavior
      model = BinaryDataModel.new(
        data: "Sample data for DI snapshot",
        metadata: {
          trigger_json_error: trigger_error,
          timestamp: Time.now
        }
      )

      # Call process method - good place to set a DI probe
      result = model.process
    end

    response_text = if trigger_error
      "BinaryDataModel processed with custom serializer error triggered (probe will be disabled). Execution time: #{(execution_time * 1000).round(2)}ms"
    else
      "BinaryDataModel processed normally. Execution time: #{(execution_time * 1000).round(2)}ms"
    end
    render plain: response_text
  end
end
