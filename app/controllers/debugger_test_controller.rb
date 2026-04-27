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
  rescue => e
    render plain: "#{e.class}: #{e.message}"
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
  rescue => e
    render plain: "#{e.class}: #{e.message}"
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
    # Resolve actual absolute paths for probe targets.
    # Relative paths like "uri/common.rb" can match vendored copies
    # (e.g. bundler/vendor/uri), so we show absolute paths.
    targets = [
      {label: "Set#add", rel: "set.rb", line: 522, description: "Adds an element to a Set", kind: "set_add"},
      {label: "Pathname#join", rel: "pathname.rb", line: 415, description: "Joins path segments", kind: "pathname_join"},
      {label: "Digest::SHA256", rel: "digest.rb", line: 56, description: "Computes a SHA256 hash (Ruby wrapper)", kind: "digest_sha256"},
    ]

    @probe_targets = targets.map do |t|
      path = resolve_stdlib_path(t[:rel])
      t.merge(path: path, coverage: probe_coverage(path, t[:line]))
    end
  end

  def stdlib_probe_run
    kind = params[:kind]
    result = case kind
    when "set_add"
      s = Set.new([1, 2, 3])
      s.add(4)
      s.add(2) # duplicate, ignored
      "Set#add: started with {1,2,3}, added 4 and 2 => #{s.to_a.sort.inspect}"
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

  private

  def resolve_stdlib_path(relative)
    File.join(RbConfig::CONFIG["rubylibdir"], relative)
  end

  # Returns :full, :partial, or :none based on whether the path is in
  # the code tracker registry and whether the target line is coverable.
  def probe_coverage(path, line)
    return :unknown unless defined?(Datadog::DI)
    code_tracker = Datadog::DI.code_tracker
    return :unknown unless code_tracker

    registry = code_tracker.send(:registry)
    return :full if registry.key?(path)

    if code_tracker.send(:instance_variable_defined?, :@per_method_registry)
      per_method = code_tracker.send(:per_method_registry)
      iseqs = per_method[path]
      if iseqs
        covers_line = iseqs.any? { |iseq| iseq.trace_points.any? { |l, _| l == line } }
        return covers_line ? :partial : :partial_no_line
      end
    end

    :none
  end

  public

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
  rescue => e
    render plain: "#{e.class}: #{e.message}"
  end
end
