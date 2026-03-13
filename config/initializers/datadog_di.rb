# Datadog Dynamic Instrumentation Configuration

Datadog.configure do |c|
  c.dynamic_instrumentation.internal.development = true
end

# Datadog Dynamic Instrumentation Custom Serializers

# Register custom serializer for ExpensiveModel
Rails.application.config.to_prepare do
  # Rails.application.config.to_prepare ensures this runs after models are loaded
  # and re-runs in development mode when code is reloaded

  Datadog::DI::Serializer.register(
    condition: ->(value) { value.is_a?(ExpensiveModel) }
  ) do |serializer, value, name:, depth:|
    # This will be called when ExpensiveModel is captured in a snapshot
    # The fibonacci computation happens during serialization, making it "expensive"

    fib_result = ExpensiveModel.fibonacci(value.n)

    {
      type: 'ExpensiveModel',
      fields: {
        data: serializer.serialize_value(value.data, name: :data, depth: depth - 1),
        n: serializer.serialize_value(value.n, name: :n, depth: depth - 1),
        fibonacci_result: serializer.serialize_value(fib_result, name: :fibonacci_result, depth: depth - 1),
        computation_note: serializer.serialize_value(
          "Computed fibonacci(#{value.n}) = #{fib_result}",
          name: :computation_note,
          depth: depth - 1,
        ),
      },
    }
  end

  # Register custom serializer for BinaryDataModel that returns binary data
  # This serializer returns a binary string with all byte values 0-255, which
  # cannot be JSON-encoded and will trigger JSON::GeneratorError
  Datadog::DI::Serializer.register(
    condition: lambda { |value|
      value.is_a?(BinaryDataModel) && value.metadata[:trigger_json_error]
    }
  ) do |serializer, value, name:, depth:|
    # Create binary string with all byte values from 0 to 255
    # This matches the test pattern from spec/datadog/di/serializer_spec.rb
    binary_string = (0..255).map { |b| b.chr(Encoding::ASCII_8BIT) }.join

    {
      type: 'BinaryDataModel',
      data: binary_string,  # This will cause JSON::GeneratorError
      note: 'This binary data cannot be JSON-encoded'
    }
  end

  # Fallback serializer for BinaryDataModel when trigger_json_error is false
  Datadog::DI::Serializer.register(
    condition: ->(value) { value.is_a?(BinaryDataModel) }
  ) do |serializer, value, name:, depth:|
    {
      type: 'BinaryDataModel',
      fields: {
        data: serializer.serialize_value(value.data, name: :data, depth: depth - 1),
        metadata: serializer.serialize_value(value.metadata, name: :metadata, depth: depth - 1),
      }
    }
  end
end
