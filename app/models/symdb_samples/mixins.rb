# frozen_string_literal: true

# Exercises: include, prepend, extend — modules mixed into classes.
# Expected:
#   Mixins::MixinUser: included_modules includes Serializable and Auditable
#                      prepended_modules includes Timestamped
module SymdbSamples
  module Mixins
    # A module to be included — adds instance methods
    module Serializable
      def to_json_str
        instance_variables.each_with_object({}) { |var, h|
          h[var.to_s.delete('@')] = instance_variable_get(var)
        }.to_json
      end

      def serialize
        instance_variables.map { |v| [v, instance_variable_get(v)] }.to_h
      end
    end

    # A module to be included — adds instance methods
    module Auditable
      def audit_log
        "#{self.class.name} accessed at #{Time.now}"
      end

      def changed?
        false
      end
    end

    # A module to be prepended — wraps existing methods
    module Timestamped
      def initialize(*)
        super
        @created_at = Time.now
      end

      def created_at
        @created_at
      end
    end

    # A module to be extended — adds class-level methods
    module ClassFinder
      def model_name
        name.split('::').last
      end
    end

    # Exercises: class with include + prepend + extend
    class MixinUser
      include Serializable
      include Auditable
      prepend Timestamped
      extend ClassFinder

      attr_accessor :name, :value

      def initialize(name, value)
        @name  = name
        @value = value
      end

      def display
        "#{name}: #{value}"
      end
    end

    # Exercises: Rails-style concern using ActiveSupport::Concern
    module SampleConcern
      extend ActiveSupport::Concern

      included do
        # e.g. validates :name, presence: true
      end

      module ClassMethods
        def find_by_sample(value)
          nil # placeholder
        end
      end

      def concern_method
        "from concern"
      end
    end
  end
end
