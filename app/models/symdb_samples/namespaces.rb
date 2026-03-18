# frozen_string_literal: true

# Exercises: Namespaced and deeply nested classes/modules.
# Expected:
#   - Each class extracted as standalone root PACKAGE scope (findable by full name)
#   - Namespace-only modules extracted via const_source_location fallback (Ruby 2.7+)
#   - Namespaces::Outer: MODULE scope with nested CLASS scopes + own methods
#   - Namespaces::Outer2: namespace-only MODULE, found via const_source_location
#   - Namespaces::Deep::A::B::C: deeply nested class
module SymdbSamples
  module Namespaces
    # Namespace module with its own methods + nested classes.
    # Expected: MODULE scope with METHOD scopes AND nested CLASS scopes.
    module Outer
      OUTER_CONSTANT = 'outer'

      def self.outer_method(x)
        x * 2
      end

      class Inner
        def initialize(value)
          @value = value
        end

        def double
          @value * 2
        end

        def to_s
          "Inner(#{@value})"
        end
      end

      class AnotherInner
        def initialize(a, b)
          @a = a
          @b = b
        end

        def combine
          "#{@a}+#{@b}"
        end
      end
    end

    # Namespace-only module (no methods) — found via const_source_location on Ruby 2.7+.
    module Outer2
      class Nested
        def hello
          "hello from Outer2::Nested"
        end
      end
    end

    # Deeply nested: exercises A::B::C pattern.
    module Deep
      module A
        module B
          class C
            DEPTH = 3

            def initialize(label)
              @label = label
            end

            def depth
              DEPTH
            end

            def label
              @label
            end
          end
        end
      end
    end
  end
end
