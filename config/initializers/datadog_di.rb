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
end
