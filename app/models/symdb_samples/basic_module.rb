# frozen_string_literal: true

# Exercises: MODULE scope, module-level constants (STATIC_FIELD), module methods.
# Expected: MODULE scope with STATIC_FIELD symbols and METHOD scopes.
module SymdbSamples
  module BasicModule
    VERSION = '1.0'
    MAX_SIZE = 100

    def self.greet(name)
      "Hello, #{name}"
    end

    def self.version
      VERSION
    end
  end

  # Exercises: Empty module — no methods, no constants.
  # Expected: extractor returns nil (no source_location, no const_source_location fallback).
  module EmptyModule
  end

  # Exercises: Module with only an included block (concern-style).
  # No direct `def` methods — only a ClassMethods submodule and `included` block.
  # Expected: MODULE scope found via const_source_location fallback (ClassMethods is a constant).
  module ConcernLikeModule
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_sample
        true
      end
    end

    # Instance method mixed in to the including class
    def sample_description
      "I am a sample concern"
    end
  end
end
