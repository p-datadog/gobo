# frozen_string_literal: true

# Exercises: define_method, Struct, attr_accessor, class << self (eigenclass).
# Expected: dynamically defined methods appear as METHOD scopes (define_method records
# the source_location of the define_method call itself).
module SymdbSamples
  module Metaprogramming
    class DynamicMethods
      # define_method with a block — no args
      [:foo, :bar, :baz].each do |name|
        define_method(name) do
          "#{name} result"
        end
      end

      # define_method with explicit parameters
      define_method(:computed) do |x, y|
        x + y
      end

      # define_method with keyword args
      define_method(:keyword_meta) do |name:, value: nil|
        "#{name}=#{value}"
      end

      # Regular method alongside dynamic ones — for comparison
      def regular_method(arg)
        arg.to_s
      end
    end

    # Exercises: Struct-based class with user-defined methods.
    # Expected: CLASS scope (Struct subclass is a Class) with user-defined METHOD scopes.
    Point = Struct.new(:x, :y) do
      def distance_to(other)
        Math.sqrt((x - other.x)**2 + (y - other.y)**2)
      end

      def to_s
        "(#{x}, #{y})"
      end

      def +(other)
        Point.new(x + other.x, y + other.y)
      end
    end

    # Exercises: class using class << self (eigenclass) for class methods.
    # Class methods not uploaded by default; only visible with upload_class_methods: true.
    class SingletonMethods
      class << self
        def create(attrs = {})
          new(attrs)
        end

        def describe
          "SingletonMethods class"
        end

        def find(_id)
          nil
        end
      end

      def initialize(attrs = {})
        @attrs = attrs
      end

      def to_h
        @attrs
      end
    end
  end
end
