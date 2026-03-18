# frozen_string_literal: true

# Exercises: All Ruby parameter types, all visibility levels, attr_accessor/reader/writer,
# and methods with exception handling.
# Expected: METHOD scopes with ARG symbols for each parameter kind.
module SymdbSamples
  class MethodVarieties
    attr_accessor :full_name   # generates reader + writer (2 METHOD scopes)
    attr_reader   :id          # generates reader only
    attr_writer   :status      # generates writer only

    def initialize(id, full_name, status = :active)
      @id        = id
      @full_name = full_name
      @status    = status
    end

    # Required positional args
    def add(a, b)
      a + b
    end

    # Optional arg with default
    def greet(name, greeting = 'Hello')
      "#{greeting}, #{name}"
    end

    # Splat (rest) arg
    def sum(*numbers)
      numbers.sum
    end

    # Keyword args (required and optional)
    def configure(host:, port: 80, ssl: false)
      "#{ssl ? 'https' : 'http'}://#{host}:#{port}"
    end

    # Double-splat (keyrest)
    def log(message, **options)
      "[#{options[:level] || 'info'}] #{message}"
    end

    # Block parameter — should be skipped by extractor (not an ARG symbol)
    def transform(value, &block)
      block ? block.call(value) : value
    end

    # Mixed: positional + keyword + splat + block
    def complex(required, optional = nil, *rest, keyword:, keyrest: nil, **opts, &blk)
      [required, optional, rest, keyword, keyrest, opts, blk]
    end

    # Zero-arg method
    def ping
      'pong'
    end

    # Method with begin/rescue/ensure
    def safe_divide(a, b)
      begin
        a / b
      rescue ZeroDivisionError => e
        "Error: #{e.message}"
      ensure
        # cleanup
      end
    end

    protected

    def protected_helper(data)
      data.to_s
    end

    private

    def private_compute(x, y)
      x * y
    end
  end
end
