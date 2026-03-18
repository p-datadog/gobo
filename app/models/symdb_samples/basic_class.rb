# frozen_string_literal: true

# Exercises: CLASS scope with instance methods, class methods, constants, class variables.
# Also exercises: public/protected/private visibility.
# Expected: PACKAGE(BasicClass) -> CLASS(BasicClass) with METHOD scopes and STATIC_FIELD symbols.
module SymdbSamples
  class BasicClass
    GREETING = 'Hello'
    @@instance_count = 0

    def initialize(name)
      @@instance_count += 1
      @name = name
    end

    # Public instance method with required arg
    def greet
      "#{GREETING}, I am #{@name}"
    end

    # Public instance method with optional arg
    def describe(verbose = false)
      verbose ? "BasicClass(#{@name}, count=#{@@instance_count})" : @name
    end

    # Class method (not uploaded by default — requires upload_class_methods: true)
    def self.instance_count
      @@instance_count
    end

    def self.reset
      @@instance_count = 0
    end

    protected

    def internal_state
      { name: @name, count: @@instance_count }
    end

    private

    def secret
      "shh"
    end
  end

  # Exercises: Empty class — no methods, no constants, no class variables.
  # Expected: extractor returns nil (no source_location).
  class EmptyClass
  end

  # Exercises: Class with only constants (no methods).
  # Expected: on Ruby 2.7+ extractor finds it via const_source_location; nil on older Ruby.
  class ConstantsOnlyClass
    STATUS_PENDING  = :pending
    STATUS_ACTIVE   = :active
    STATUS_INACTIVE = :inactive
  end

  # Exercises: Class with only class variables (no methods).
  # Expected: extractor returns nil — class variables have no source_location and
  # const_source_location only fires for non-class-value constants.
  class ClassVariablesOnlyClass
    @@counter = 0
    @@label = 'test'
  end
end
