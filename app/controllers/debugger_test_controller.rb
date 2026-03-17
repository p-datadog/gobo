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

  def json_error
    # Render the JSON encoding error demo page
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

    status_text = trigger_error ? "triggered (probe will be disabled)" : "normal operation"
    response_text = "BinaryDataModel processed with JSON error #{status_text}. Execution time: #{(execution_time * 1000).round(2)}ms"
    render plain: response_text
  end
end
